import Foundation
import SkipSQL

public enum CompetitionRepositoryError: Error {
    /// 指定した id の大会が無い
    case notFound(id: Int64)
    /// 列の値が想定した型・値でない(スキーマと Swift 側のズレ)
    case unreadableColumn(name: String)
    /// エントリー種目に `both` は使えない(§6 'singles' | 'doubles')
    case invalidEntryDiscipline(discipline: Discipline)
}

/// 大会(`competition`)とエントリー種目(`competition_entry`)の永続化。
///
/// **`is_target` を種目ごとに最大 1 件に保つのはこのクラスの責務。**
/// SQL の制約では表現できないので(§6 の「アプリ側で担保」)、目標を立てる書き込みの
/// たびに同じ種目の他の大会の目標を解除する。
///
/// `now` はテストからクロックを差し替えるための注入点。
public final class CompetitionRepository {
    private let db: SQLContext
    private let now: () -> Date
    private let timestamps = SQLTimestamp()

    public init(db: SQLContext, now: @escaping () -> Date = { Date() }) {
        self.db = db
        self.now = now
    }

    /// SELECT の列。並びは `decode(_:)` の添字と対応している。
    /// **足すときは末尾に。** 途中に入れると既存の添字がずれる。
    private static let columns = "id, name, event_date, venue, created_at, aim"
    /// JOIN で使う `competition` 側の列。`columns` と同じ並びを保つこと。
    private static let prefixedColumns = "c.id, c.name, c.event_date, c.venue, c.created_at, c.aim"

    // MARK: - Create

    /// 大会をエントリー種目つきで保存する。
    ///
    /// `entries` に `isTarget = true` が含まれていれば、同じ種目の他の大会の目標は解除される。
    @discardableResult
    public func create(name: String,
                       eventDate: Date,
                       venue: String? = nil,
                       entries: [CompetitionEntry] = []) throws -> Competition {
        try validate(entries)
        return try db.transaction {
            try db.exec(sql: "INSERT INTO competition (name, event_date, venue, created_at) VALUES (?, ?, ?, ?)",
                        parameters: [
                            SQLValue.text(name),
                            SQLValue.text(timestamps.text(from: eventDate)),
                            textValue(venue),
                            SQLValue.text(timestamps.text(from: now())),
                        ])
            let id = db.lastInsertRowID
            try replaceEntries(competitionId: id, entries: entries)
            return try require(id: id)
        }
    }

    // MARK: - Read

    public func fetch(id: Int64) throws -> Competition? {
        let rows = try db.selectAll(sql: "SELECT \(CompetitionRepository.columns) FROM competition WHERE id = ?",
                                    parameters: [.long(id)])
        guard let row = rows.first else {
            return nil
        }
        return try decode(row)
    }

    /// 日付順(古い順)。これからの大会と終了した大会を分けたいときは
    /// `fetchUpcoming(asOf:)` / `fetchFinished(asOf:)` を使う。
    public func fetchAll() throws -> [Competition] {
        let rows = try db.selectAll(sql: "SELECT \(CompetitionRepository.columns) FROM competition ORDER BY event_date, id")
        return try decodeAll(rows)
    }

    /// これからの大会。近いものが先(§7.5)。
    ///
    /// - Parameter asOf: 基準時刻。**この時刻ちょうどの大会は「これから」に含む。**
    ///   当日の大会を当日いっぱい「これから」として扱いたいので、呼び出し側は
    ///   今日の 0 時を渡す(当日の朝に「終了した大会」へ落ちないようにするため)。
    public func fetchUpcoming(asOf: Date) throws -> [Competition] {
        let rows = try db.selectAll(sql: "SELECT \(CompetitionRepository.columns) FROM competition WHERE event_date >= ? ORDER BY event_date, id",
                                    parameters: [.text(timestamps.text(from: asOf))])
        return try decodeAll(rows)
    }

    /// 終了した大会。新しいものが先(§7.5)。
    public func fetchFinished(asOf: Date) throws -> [Competition] {
        let rows = try db.selectAll(sql: "SELECT \(CompetitionRepository.columns) FROM competition WHERE event_date < ? ORDER BY event_date DESC, id DESC",
                                    parameters: [.text(timestamps.text(from: asOf))])
        return try decodeAll(rows)
    }

    public func fetchEntries(competitionId: Int64) throws -> [CompetitionEntry] {
        let rows = try db.selectAll(sql: "SELECT discipline, is_target FROM competition_entry WHERE competition_id = ? ORDER BY id",
                                    parameters: [.long(competitionId)])
        var entries: [CompetitionEntry] = []
        for row in rows {
            entries.append(try decodeEntry(row))
        }
        return entries
    }

    /// 種目の目標大会(§7.5)。未設定なら nil。
    public func fetchTarget(discipline: Discipline) throws -> Competition? {
        try requireEntryDiscipline(discipline)
        let rows = try db.selectAll(sql: """
            SELECT \(CompetitionRepository.prefixedColumns)
            FROM competition c
            JOIN competition_entry e ON e.competition_id = c.id
            WHERE e.discipline = ? AND e.is_target = 1
            LIMIT 1
            """,
            parameters: [.text(discipline.rawValue)])
        guard let row = rows.first else {
            return nil
        }
        return try decode(row)
    }

    // MARK: - 課題との紐付け(§7.5 この大会までに)

    /// この大会に紐付ける課題を `issueIds` の集合に合わせる。
    public func setIssues(_ issueIds: [Int64], for competitionId: Int64) throws {
        try db.transaction {
            try db.exec(sql: "DELETE FROM issue_competition WHERE competition_id = ?",
                        parameters: [.long(competitionId)])
            for issueId in issueIds {
                try db.exec(sql: "INSERT INTO issue_competition (issue_id, competition_id) VALUES (?, ?)",
                            parameters: [SQLValue.long(issueId), SQLValue.long(competitionId)])
            }
        }
    }

    public func fetchIssueIds(competitionId: Int64) throws -> [Int64] {
        let rows = try db.selectAll(sql: "SELECT issue_id FROM issue_competition WHERE competition_id = ? ORDER BY issue_id",
                                    parameters: [.long(competitionId)])
        var ids: [Int64] = []
        for row in rows {
            if let id = row[0].longValue {
                ids.append(id)
            }
        }
        return ids
    }

    // MARK: - 大会後の振り返り(§7.5 種目ごとに 1 セット)

    /// 振り返りを保存する。**全項目任意。** 同じ種目に 2 件は作らない。
    public func saveReview(competitionId: Int64,
                           discipline: Discipline,
                           result: String? = nil,
                           wentWell: String? = nil,
                           nextAction: String? = nil,
                           neededResources: String? = nil) throws {
        try requireEntryDiscipline(discipline)
        // UPSERT は SQLite 3.24 以降。Android API 28 は 3.22 なので使わない
        let existing = try fetchReview(competitionId: competitionId, discipline: discipline)
        let createdAt = existing?.createdAt ?? now()
        try db.exec(sql: "DELETE FROM competition_review WHERE competition_id = ? AND discipline = ?",
                    parameters: [SQLValue.long(competitionId), SQLValue.text(discipline.rawValue)])
        try db.exec(sql: """
            INSERT INTO competition_review (competition_id, discipline, result, went_well, next_action, needed_resources, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            parameters: [
                SQLValue.long(competitionId),
                SQLValue.text(discipline.rawValue),
                textValue(result),
                textValue(wentWell),
                textValue(nextAction),
                textValue(neededResources),
                SQLValue.text(timestamps.text(from: createdAt)),
            ])
    }

    public func fetchReview(competitionId: Int64, discipline: Discipline) throws -> CompetitionReview? {
        let rows = try db.selectAll(sql: "SELECT id, competition_id, discipline, result, went_well, next_action, needed_resources, created_at FROM competition_review WHERE competition_id = ? AND discipline = ?",
                                    parameters: [SQLValue.long(competitionId), SQLValue.text(discipline.rawValue)])
        guard let row = rows.first else {
            return nil
        }
        return try decodeReview(row)
    }

    private func decodeReview(_ row: [SQLValue]) throws -> CompetitionReview {
        guard let id = row[0].longValue else {
            throw CompetitionRepositoryError.unreadableColumn(name: "id")
        }
        guard let competitionId = row[1].longValue else {
            throw CompetitionRepositoryError.unreadableColumn(name: "competition_id")
        }
        guard let disciplineRaw = row[2].textValue,
              let discipline = Discipline(rawValue: disciplineRaw) else {
            throw CompetitionRepositoryError.unreadableColumn(name: "discipline")
        }
        guard let createdAtText = row[7].textValue,
              let createdAt = timestamps.date(from: createdAtText) else {
            throw CompetitionRepositoryError.unreadableColumn(name: "created_at")
        }
        return CompetitionReview(id: id,
                                 competitionId: competitionId,
                                 discipline: discipline,
                                 result: row[3].textValue,
                                 wentWell: row[4].textValue,
                                 nextAction: row[5].textValue,
                                 neededResources: row[6].textValue,
                                 createdAt: createdAt)
    }

    // MARK: - Update

    /// 大会を更新し、エントリー種目を `entries` の内容で置き換える。
    ///
    /// `created_at` は更新しない。エントリーは差分ではなく集合の置き換えで、
    /// `entries` に含まれない種目の行は消える。
    @discardableResult
    public func update(_ competition: Competition, entries: [CompetitionEntry]) throws -> Competition {
        try validate(entries)
        return try db.transaction {
            try db.exec(sql: "UPDATE competition SET name = ?, event_date = ?, venue = ?, aim = ? WHERE id = ?",
                        parameters: [
                            SQLValue.text(competition.name),
                            SQLValue.text(timestamps.text(from: competition.eventDate)),
                            textValue(competition.venue),
                            textValue(competition.aim),
                            SQLValue.long(competition.id),
                        ])
            try replaceEntries(competitionId: competition.id, entries: entries)
            return try require(id: competition.id)
        }
    }

    // MARK: - Delete

    /// 大会を削除する。エントリー種目は `ON DELETE CASCADE` で一緒に消える。
    /// 該当が無ければ何もしない。
    public func delete(id: Int64) throws {
        try db.exec(sql: "DELETE FROM competition WHERE id = ?", parameters: [.long(id)])
    }

    // MARK: - エントリーの書き込み

    /// 既存のエントリーを全部消してから入れ直す。
    ///
    /// `UNIQUE (competition_id, discipline)` があるので追記だと 2 回目の保存で衝突する。
    /// 置き換えなら重複も取り残しも起きない。行数は多くても 2 件。
    private func replaceEntries(competitionId: Int64, entries: [CompetitionEntry]) throws {
        try db.exec(sql: "DELETE FROM competition_entry WHERE competition_id = ?",
                    parameters: [.long(competitionId)])
        for entry in entries {
            if entry.isTarget {
                try clearTarget(discipline: entry.discipline, exceptCompetitionId: competitionId)
            }
            try db.exec(sql: "INSERT INTO competition_entry (competition_id, discipline, is_target) VALUES (?, ?, ?)",
                        parameters: [
                            SQLValue.long(competitionId),
                            SQLValue.text(entry.discipline.rawValue),
                            SQLValue.long(entry.isTarget ? 1 : 0),
                        ])
        }
    }

    /// 終わった大会の目標フラグを下ろす(§7.5)。
    ///
    /// **過去の大会が「目標大会」であり続けないようにするための後始末。**
    /// 目標が空になることで、ホームが次の目標大会を促せるようになる
    /// (残したままだと `fetchTarget` が過去の大会を返し、カウントダウンも促しも出ない)。
    ///
    /// - Parameter asOf: 基準時刻。**この時刻ちょうどの大会は残す。**
    ///   当日いっぱいは目標のままにしたいので、呼び出し側は今日の 0 時を渡す
    ///   (`fetchUpcoming(asOf:)` と同じ約束)。
    ///
    /// エントリー種目の行そのものは消さない(出場した記録は残す)。
    public func clearFinishedTargets(asOf: Date) throws {
        try db.exec(sql: """
            UPDATE competition_entry SET is_target = 0
            WHERE is_target = 1 AND competition_id IN (
              SELECT id FROM competition WHERE event_date < ?
            )
            """,
            parameters: [.text(timestamps.text(from: asOf))])
    }

    /// 同じ種目の他の大会の目標を解除する。消すのは目標フラグだけで、エントリー自体は残す。
    private func clearTarget(discipline: Discipline, exceptCompetitionId: Int64) throws {
        try db.exec(sql: "UPDATE competition_entry SET is_target = 0 WHERE discipline = ? AND competition_id != ?",
                    parameters: [
                        SQLValue.text(discipline.rawValue),
                        SQLValue.long(exceptCompetitionId),
                    ])
    }

    // MARK: - 変換

    private func validate(_ entries: [CompetitionEntry]) throws {
        for entry in entries {
            try requireEntryDiscipline(entry.discipline)
        }
    }

    private func requireEntryDiscipline(_ discipline: Discipline) throws {
        if discipline == Discipline.both {
            throw CompetitionRepositoryError.invalidEntryDiscipline(discipline: discipline)
        }
    }

    private func require(id: Int64) throws -> Competition {
        guard let competition = try fetch(id: id) else {
            throw CompetitionRepositoryError.notFound(id: id)
        }
        return competition
    }

    private func decodeAll(_ rows: [[SQLValue]]) throws -> [Competition] {
        var competitions: [Competition] = []
        for row in rows {
            competitions.append(try decode(row))
        }
        return competitions
    }

    private func decode(_ row: [SQLValue]) throws -> Competition {
        guard let id = row[0].longValue else {
            throw CompetitionRepositoryError.unreadableColumn(name: "id")
        }
        guard let name = row[1].textValue else {
            throw CompetitionRepositoryError.unreadableColumn(name: "name")
        }
        guard let eventDateText = row[2].textValue,
              let eventDate = timestamps.date(from: eventDateText) else {
            throw CompetitionRepositoryError.unreadableColumn(name: "event_date")
        }
        guard let createdAtText = row[4].textValue,
              let createdAt = timestamps.date(from: createdAtText) else {
            throw CompetitionRepositoryError.unreadableColumn(name: "created_at")
        }

        return Competition(id: id,
                           name: name,
                           eventDate: eventDate,
                           venue: row[3].textValue,
                           aim: row[5].textValue,
                           createdAt: createdAt)
    }

    private func decodeEntry(_ row: [SQLValue]) throws -> CompetitionEntry {
        guard let disciplineRaw = row[0].textValue,
              let discipline = Discipline(rawValue: disciplineRaw) else {
            throw CompetitionRepositoryError.unreadableColumn(name: "discipline")
        }
        guard let isTarget = row[1].longValue else {
            throw CompetitionRepositoryError.unreadableColumn(name: "is_target")
        }

        // Int64 と Int リテラルの != は Kotlin で通らないので型を揃える
        return CompetitionEntry(discipline: discipline, isTarget: isTarget != Int64(0))
    }

    private func textValue(_ value: String?) -> SQLValue {
        guard let value = value else {
            return .null
        }
        return .text(value)
    }
}
