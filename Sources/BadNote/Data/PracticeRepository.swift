import Foundation
import SkipSQL

public enum PracticeRepositoryError: Error {
    /// 指定した id の練習ログが無い
    case notFound(id: Int64)
    /// 列の値が想定した型・値でない(スキーマと Swift 側のズレ)
    case unreadableColumn(name: String)
}

/// 練習ログ(`practice`)と手応え(`focus_record`)の永続化。
///
/// 練習ログと手応えは常に 1 トランザクションで保存する。片方だけが残ると
/// 「時間は記録されたのに手応えが消えた」状態になり、§7.2 の保存後表示が嘘になる。
///
/// `now` はテストからクロックを差し替えるための注入点。
public final class PracticeRepository {
    private let db: SQLContext
    private let now: () -> Date
    private let timestamps = SQLTimestamp()

    public init(db: SQLContext, now: @escaping () -> Date = { Date() }) {
        self.db = db
        self.now = now
    }

    /// SELECT の列。並びは `decodePractice(_:)` の添字と対応している。
    private static let columns = "id, practice_date, minutes, kind, created_at"
    /// 並びは `decodeFocusRecord(_:)` の添字と対応している。
    private static let focusColumns = "id, practice_id, issue_id, result"

    // MARK: - Create

    /// 練習ログと手応えをまとめて保存する。
    ///
    /// §7.2 全項目任意。時間 0・種類なし・手応えなしでも保存できる。
    @discardableResult
    public func create(practiceDate: Date,
                       minutes: Int = 0,
                       kind: PracticeKind? = nil,
                       focus: [FocusEntry] = []) throws -> Practice {
        return try db.transaction {
            try db.exec(sql: "INSERT INTO practice (practice_date, minutes, kind, created_at) VALUES (?, ?, ?, ?)",
                        parameters: [
                            SQLValue.text(timestamps.text(from: practiceDate)),
                            SQLValue.long(Int64(minutes)),
                            textValue(kind?.rawValue),
                            SQLValue.text(timestamps.text(from: now())),
                        ])
            let id = db.lastInsertRowID
            try replaceFocusRecords(practiceId: id, focus: focus)
            return try require(id: id)
        }
    }

    // MARK: - Read

    public func fetch(id: Int64) throws -> Practice? {
        let rows = try db.selectAll(sql: "SELECT \(PracticeRepository.columns) FROM practice WHERE id = ?",
                                    parameters: [.long(id)])
        guard let row = rows.first else {
            return nil
        }
        return try decodePractice(row)
    }

    /// 新しい練習が先。同じ日付なら後から登録したものが先。
    public func fetchAll() throws -> [Practice] {
        let rows = try db.selectAll(sql: "SELECT \(PracticeRepository.columns) FROM practice ORDER BY practice_date DESC, id DESC")
        var practices: [Practice] = []
        for row in rows {
            practices.append(try decodePractice(row))
        }
        return practices
    }

    public func fetchFocusRecords(practiceId: Int64) throws -> [FocusRecord] {
        let rows = try db.selectAll(sql: "SELECT \(PracticeRepository.focusColumns) FROM focus_record WHERE practice_id = ? ORDER BY id",
                                    parameters: [.long(practiceId)])
        var records: [FocusRecord] = []
        for row in rows {
            records.append(try decodeFocusRecord(row))
        }
        return records
    }

    /// 課題ごとの手応え履歴。**新しい練習が先**(§3.2 のレベルアップ判定に渡す形)。
    ///
    /// 未入力(NULL)も nil として含める。連続の数え方は `LevelUpSuggestion` 側の責務。
    public func fetchFocusResults(issueId: Int64) throws -> [FocusResult?] {
        let rows = try db.selectAll(sql: """
            SELECT f.result
            FROM focus_record f
            JOIN practice p ON p.id = f.practice_id
            WHERE f.issue_id = ?
            ORDER BY p.practice_date DESC, p.id DESC
            """,
            parameters: [.long(issueId)])
        var results: [FocusResult?] = []
        for row in rows {
            results.append(try decodeResult(row[0]))
        }
        return results
    }

    /// 練習ログの総数。§7.1 の「数回使った後に促す」の判定材料。
    public func count() throws -> Int {
        let rows = try db.selectAll(sql: "SELECT COUNT(*) FROM practice")
        guard let count = rows.first?.first?.longValue else {
            return 0
        }
        return Int(count)
    }

    /// 指定した日時より**後**の練習件数(§4.2 の left_focus 判定)。
    ///
    /// 重点を外れた時刻ちょうどの練習は含めない。
    public func countPractices(after date: Date) throws -> Int {
        let rows = try db.selectAll(sql: "SELECT COUNT(*) FROM practice WHERE practice_date > ?",
                                    parameters: [.text(timestamps.text(from: date))])
        guard let count = rows.first?.first?.longValue else {
            return 0
        }
        return Int(count)
    }

    /// 課題ごとの累計時間(§6)。値は保持せず、その都度集計する。
    ///
    /// **1 練習の minutes は重点課題それぞれに満額計上する(按分しない)。**
    /// 90 分の練習で 3 つの重点を意識したなら、3 つとも 90 分。
    /// 手応え未入力(`result IS NULL`)の行も対象に含める。
    public func totalMinutes(issueId: Int64) throws -> Int {
        let rows = try db.selectAll(sql: """
            SELECT SUM(p.minutes)
            FROM focus_record f
            JOIN practice p ON p.id = f.practice_id
            WHERE f.issue_id = ?
            """,
            parameters: [.long(issueId)])
        // 1 件も無いとき SUM は NULL
        guard let total = rows.first?.first?.longValue else {
            return 0
        }
        return Int(total)
    }

    /// 期間内の練習時間の合計。`from` 以上 `to` 未満(半開区間)。
    ///
    /// §7.2 の「今月の累計」に使う。月をまたぐ判定を呼び出し側に寄せるため、
    /// 終端は含めない(翌月の頭をそのまま渡せる)。
    public func totalMinutes(from: Date, to: Date) throws -> Int {
        let rows = try db.selectAll(sql: "SELECT SUM(minutes) FROM practice WHERE practice_date >= ? AND practice_date < ?",
                                    parameters: [
                                        .text(timestamps.text(from: from)),
                                        .text(timestamps.text(from: to)),
                                    ])
        // 1 件も無いとき SUM は NULL
        guard let total = rows.first?.first?.longValue else {
            return 0
        }
        return Int(total)
    }

    // MARK: - Update

    /// 練習ログを更新し、手応えを `focus` の内容で置き換える。
    ///
    /// `created_at` は更新しない。手応えは差分ではなく集合の置き換えで、
    /// `focus` に含まれない課題の行は消える(重点を組み替えた後の編集を想定)。
    @discardableResult
    public func update(_ practice: Practice, focus: [FocusEntry]) throws -> Practice {
        return try db.transaction {
            try db.exec(sql: "UPDATE practice SET practice_date = ?, minutes = ?, kind = ? WHERE id = ?",
                        parameters: [
                            SQLValue.text(timestamps.text(from: practice.practiceDate)),
                            SQLValue.long(Int64(practice.minutes)),
                            textValue(practice.kind?.rawValue),
                            SQLValue.long(practice.id),
                        ])
            try replaceFocusRecords(practiceId: practice.id, focus: focus)
            return try require(id: practice.id)
        }
    }

    // MARK: - Delete

    /// 練習ログを削除する。手応えは `ON DELETE CASCADE` で一緒に消える。
    /// 該当が無ければ何もしない。
    public func delete(id: Int64) throws {
        try db.exec(sql: "DELETE FROM practice WHERE id = ?", parameters: [.long(id)])
    }

    // MARK: - 手応えの書き込み

    /// 既存の手応えを全部消してから入れ直す。
    ///
    /// `UNIQUE (practice_id, issue_id)` があるので追記だと 2 回目の保存で衝突する。
    /// 置き換えなら重複も取り残しも起きない。行数は多くても重点 3 件分。
    /// (`focus_record.id` は保存し直すたびに変わるが、id を参照する所は無い)
    private func replaceFocusRecords(practiceId: Int64, focus: [FocusEntry]) throws {
        try db.exec(sql: "DELETE FROM focus_record WHERE practice_id = ?", parameters: [.long(practiceId)])
        for entry in focus {
            try db.exec(sql: "INSERT INTO focus_record (practice_id, issue_id, result) VALUES (?, ?, ?)",
                        parameters: [
                            SQLValue.long(practiceId),
                            SQLValue.long(entry.issueId),
                            textValue(entry.result?.rawValue),
                        ])
        }
    }

    // MARK: - 変換

    private func require(id: Int64) throws -> Practice {
        guard let practice = try fetch(id: id) else {
            throw PracticeRepositoryError.notFound(id: id)
        }
        return practice
    }

    private func decodePractice(_ row: [SQLValue]) throws -> Practice {
        guard let id = row[0].longValue else {
            throw PracticeRepositoryError.unreadableColumn(name: "id")
        }
        guard let practiceDateText = row[1].textValue,
              let practiceDate = timestamps.date(from: practiceDateText) else {
            throw PracticeRepositoryError.unreadableColumn(name: "practice_date")
        }
        guard let minutes = row[2].longValue else {
            throw PracticeRepositoryError.unreadableColumn(name: "minutes")
        }
        guard let createdAtText = row[4].textValue,
              let createdAt = timestamps.date(from: createdAtText) else {
            throw PracticeRepositoryError.unreadableColumn(name: "created_at")
        }

        return Practice(id: id,
                        practiceDate: practiceDate,
                        minutes: Int(minutes),
                        kind: try decodeKind(row[3]),
                        createdAt: createdAt)
    }

    private func decodeFocusRecord(_ row: [SQLValue]) throws -> FocusRecord {
        guard let id = row[0].longValue else {
            throw PracticeRepositoryError.unreadableColumn(name: "id")
        }
        guard let practiceId = row[1].longValue else {
            throw PracticeRepositoryError.unreadableColumn(name: "practice_id")
        }
        guard let issueId = row[2].longValue else {
            throw PracticeRepositoryError.unreadableColumn(name: "issue_id")
        }

        return FocusRecord(id: id,
                           practiceId: practiceId,
                           issueId: issueId,
                           result: try decodeResult(row[3]))
    }

    /// NULL は未選択。値が入っているのに未知の文字列ならスキーマとのズレなので投げる。
    private func decodeKind(_ value: SQLValue) throws -> PracticeKind? {
        guard let text = value.textValue else {
            return nil
        }
        guard let kind = PracticeKind(rawValue: text) else {
            throw PracticeRepositoryError.unreadableColumn(name: "kind")
        }
        return kind
    }

    /// NULL は未入力(§7.2 手応え未選択でも保存できる)。
    private func decodeResult(_ value: SQLValue) throws -> FocusResult? {
        guard let text = value.textValue else {
            return nil
        }
        guard let result = FocusResult(rawValue: text) else {
            throw PracticeRepositoryError.unreadableColumn(name: "result")
        }
        return result
    }

    private func textValue(_ value: String?) -> SQLValue {
        guard let value = value else {
            return .null
        }
        return .text(value)
    }
}
