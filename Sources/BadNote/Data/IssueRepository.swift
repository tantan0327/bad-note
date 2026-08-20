import Foundation
import SkipSQL

public enum IssueRepositoryError: Error {
    /// 指定した id の課題が無い
    case notFound(id: Int64)
    /// 列の値が想定した型・値でない(スキーマと Swift 側のズレ)
    case unreadableColumn(name: String)
}

/// 課題(`issue` テーブル)の永続化。SQL はこのクラスの中にだけ書く。
///
/// `now` はテストからクロックを差し替えるための注入点。created_at / updated_at は
/// 呼び出し側ではなくこのクラスが決める。
public final class IssueRepository {
    private let db: SQLContext
    private let now: () -> Date
    private let timestamps = SQLTimestamp()

    public init(db: SQLContext, now: @escaping () -> Date = { Date() }) {
        self.db = db
        self.now = now
    }

    /// SELECT の列。並びは `decode(_:)` の添字と対応している。
    private static let columns = "id, coach_words, done_form, coach_name, discipline, mastery_level, tier, sort_order, impact, cost, status, resurface_count, last_focused_at, created_at, updated_at, archived_at, level_up_declined_level"

    // MARK: - Create

    /// 課題を 1 件登録して、保存された内容を返す。
    ///
    /// `doneForm` は任意。練習後は `coachWords` の 1 行だけで登録できる(§3.1)。
    @discardableResult
    public func create(coachWords: String,
                       doneForm: String? = nil,
                       coachName: String? = nil,
                       discipline: Discipline = .both,
                       masteryLevel: MasteryLevel = .solo,
                       tier: Tier = .someday,
                       sortOrder: Int = 0,
                       impact: Int? = nil,
                       cost: Int? = nil,
                       status: IssueStatus = .inbox) throws -> Issue {
        let timestamp = timestamps.text(from: now())
        try db.exec(sql: """
            INSERT INTO issue (coach_words, done_form, coach_name, discipline, mastery_level, tier, sort_order, impact, cost, status, resurface_count, last_focused_at, created_at, updated_at, archived_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, NULL, ?, ?, NULL)
            """,
            parameters: [
                .text(coachWords),
                textValue(doneForm),
                textValue(coachName),
                .text(discipline.rawValue),
                .long(Int64(masteryLevel.rawValue)),
                .text(tier.rawValue),
                .long(Int64(sortOrder)),
                intValue(impact),
                intValue(cost),
                .text(status.rawValue),
                .text(timestamp),
                .text(timestamp),
            ])
        return try require(id: db.lastInsertRowID)
    }

    // MARK: - Read

    public func fetch(id: Int64) throws -> Issue? {
        let rows = try db.selectAll(sql: "SELECT \(IssueRepository.columns) FROM issue WHERE id = ?",
                                    parameters: [.long(id)])
        guard let row = rows.first else {
            return nil
        }
        return try decode(row)
    }

    public func fetchAll() throws -> [Issue] {
        return try fetch()
    }

    /// 層と状態で絞り込む。層の中は手動並び順(`sortOrder`)で返す(§3.3)。
    ///
    /// 引数を省略した条件は絞り込まない。**既定で黙ってアーカイブを隠さない**ので、
    /// 隠したい画面は明示的に status を渡すこと。
    ///
    /// - 課題一覧(§7.4): `fetch(tier: .focus, statuses: [.inbox, .active])`
    /// - アーカイブ画面(§7.4): `fetch(statuses: [.archived])`
    /// - stale 判定の母集団(§4.2): `fetch(statuses: [.inbox, .active])`
    /// - タグで絞り込み(§7.4): `fetch(tagId: smash.id)`
    ///
    /// - Parameter statuses: 空配列を渡すとどの status にも該当しないものとして空を返す。
    /// - Parameter tagId: 指定するとそのタグが付いた課題だけを返す(§7.4 の絞り込み行)。
    public func fetch(tier: Tier? = nil, statuses: [IssueStatus]? = nil, tagId: Int64? = nil) throws -> [Issue] {
        if let statuses = statuses, statuses.isEmpty {
            return []
        }

        var conditions: [String] = []
        var parameters: [SQLValue] = []
        if let tier = tier {
            conditions.append("tier = ?")
            parameters.append(SQLValue.text(tier.rawValue))
        }
        if let statuses = statuses {
            var placeholders: [String] = []
            for status in statuses {
                placeholders.append("?")
                parameters.append(SQLValue.text(status.rawValue))
            }
            conditions.append("status IN (" + placeholders.joined(separator: ", ") + ")")
        }
        if let tagId = tagId {
            conditions.append("id IN (SELECT issue_id FROM issue_tag WHERE tag_id = ?)")
            parameters.append(SQLValue.long(tagId))
        }
        let whereClause = conditions.isEmpty ? "" : " WHERE " + conditions.joined(separator: " AND ")

        let rows = try db.selectAll(sql: "SELECT \(IssueRepository.columns) FROM issue" + whereClause + " ORDER BY sort_order, id",
                                    parameters: parameters)
        return try decodeAll(rows)
    }

    // MARK: - Update

    /// 課題を更新して、保存された内容を返す。
    ///
    /// `created_at` は更新しない。`updated_at` は引数の値ではなくクロックの現在時刻で上書きする。
    @discardableResult
    public func update(_ issue: Issue) throws -> Issue {
        try db.exec(sql: """
            UPDATE issue SET coach_words = ?, done_form = ?, coach_name = ?, discipline = ?, mastery_level = ?, tier = ?, sort_order = ?, impact = ?, cost = ?, status = ?, resurface_count = ?, last_focused_at = ?, updated_at = ?, archived_at = ?, level_up_declined_level = ?
            WHERE id = ?
            """,
            parameters: [
                .text(issue.coachWords),
                textValue(issue.doneForm),
                textValue(issue.coachName),
                .text(issue.discipline.rawValue),
                .long(Int64(issue.masteryLevel.rawValue)),
                .text(issue.tier.rawValue),
                .long(Int64(issue.sortOrder)),
                intValue(issue.impact),
                intValue(issue.cost),
                .text(issue.status.rawValue),
                .long(Int64(issue.resurfaceCount)),
                dateValue(issue.lastFocusedAt),
                .text(timestamps.text(from: now())),
                dateValue(issue.archivedAt),
                intValue(issue.levelUpDeclinedLevel),
                .long(issue.id),
            ])
        return try require(id: issue.id)
    }

    // MARK: - Delete

    /// 課題を削除する。該当が無ければ何もしない。
    public func delete(id: Int64) throws {
        try db.exec(sql: "DELETE FROM issue WHERE id = ?", parameters: [.long(id)])
    }

    // MARK: - 変換

    private func require(id: Int64) throws -> Issue {
        guard let issue = try fetch(id: id) else {
            throw IssueRepositoryError.notFound(id: id)
        }
        return issue
    }

    private func decodeAll(_ rows: [[SQLValue]]) throws -> [Issue] {
        var issues: [Issue] = []
        for row in rows {
            issues.append(try decode(row))
        }
        return issues
    }

    private func decode(_ row: [SQLValue]) throws -> Issue {
        guard let id = row[0].longValue else {
            throw IssueRepositoryError.unreadableColumn(name: "id")
        }
        guard let coachWords = row[1].textValue else {
            throw IssueRepositoryError.unreadableColumn(name: "coach_words")
        }
        guard let disciplineRaw = row[4].textValue,
              let discipline = Discipline(rawValue: disciplineRaw) else {
            throw IssueRepositoryError.unreadableColumn(name: "discipline")
        }
        guard let masteryRaw = row[5].longValue,
              let masteryLevel = MasteryLevel(rawValue: Int(masteryRaw)) else {
            throw IssueRepositoryError.unreadableColumn(name: "mastery_level")
        }
        guard let tierRaw = row[6].textValue,
              let tier = Tier(rawValue: tierRaw) else {
            throw IssueRepositoryError.unreadableColumn(name: "tier")
        }
        guard let sortOrder = row[7].longValue else {
            throw IssueRepositoryError.unreadableColumn(name: "sort_order")
        }
        guard let statusRaw = row[10].textValue,
              let status = IssueStatus(rawValue: statusRaw) else {
            throw IssueRepositoryError.unreadableColumn(name: "status")
        }
        guard let resurfaceCount = row[11].longValue else {
            throw IssueRepositoryError.unreadableColumn(name: "resurface_count")
        }
        guard let createdAtText = row[13].textValue,
              let createdAt = timestamps.date(from: createdAtText) else {
            throw IssueRepositoryError.unreadableColumn(name: "created_at")
        }
        guard let updatedAtText = row[14].textValue,
              let updatedAt = timestamps.date(from: updatedAtText) else {
            throw IssueRepositoryError.unreadableColumn(name: "updated_at")
        }

        return Issue(id: id,
                     coachWords: coachWords,
                     doneForm: row[2].textValue,
                     coachName: row[3].textValue,
                     discipline: discipline,
                     masteryLevel: masteryLevel,
                     tier: tier,
                     sortOrder: Int(sortOrder),
                     impact: intOrNil(row[8]),
                     cost: intOrNil(row[9]),
                     status: status,
                     resurfaceCount: Int(resurfaceCount),
                     lastFocusedAt: dateOrNil(row[12]),
                     levelUpDeclinedLevel: intOrNil(row[16]),
                     createdAt: createdAt,
                     updatedAt: updatedAt,
                     archivedAt: dateOrNil(row[15]))
    }

    private func textValue(_ value: String?) -> SQLValue {
        guard let value = value else {
            return .null
        }
        return .text(value)
    }

    private func intValue(_ value: Int?) -> SQLValue {
        guard let value = value else {
            return .null
        }
        return .long(Int64(value))
    }

    private func dateValue(_ value: Date?) -> SQLValue {
        guard let value = value else {
            return .null
        }
        return .text(timestamps.text(from: value))
    }

    private func intOrNil(_ value: SQLValue) -> Int? {
        guard let long = value.longValue else {
            return nil
        }
        return Int(long)
    }

    private func dateOrNil(_ value: SQLValue) -> Date? {
        guard let text = value.textValue else {
            return nil
        }
        return timestamps.date(from: text)
    }
}
