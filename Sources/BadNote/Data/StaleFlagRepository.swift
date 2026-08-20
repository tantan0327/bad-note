import Foundation
import SkipSQL

public enum StaleFlagRepositoryError: Error {
    case unreadableColumn(name: String)
}

/// stale の週次スナップショット(`stale_flag`)の永続化。
public final class StaleFlagRepository {
    private let db: SQLContext
    private let timestamps = SQLTimestamp()

    public init(db: SQLContext) {
        self.db = db
    }

    /// スナップショットを丸ごと入れ替える(§4.3 全削除してから再 INSERT)。
    public func replaceAll(_ flags: [StaleFlag]) throws {
        try db.transaction {
            try db.exec(sql: "DELETE FROM stale_flag")
            for flag in flags {
                try db.exec(sql: "INSERT INTO stale_flag (issue_id, reason, evaluated_at) VALUES (?, ?, ?)",
                            parameters: [
                                SQLValue.long(flag.issueId),
                                SQLValue.text(flag.reason.rawValue),
                                SQLValue.text(timestamps.text(from: flag.evaluatedAt)),
                            ])
            }
        }
    }

    public func fetchAll() throws -> [StaleFlag] {
        let rows = try db.selectAll(sql: "SELECT issue_id, reason, evaluated_at FROM stale_flag ORDER BY issue_id")
        var flags: [StaleFlag] = []
        for row in rows {
            flags.append(try decode(row))
        }
        return flags
    }

    /// 3 択のどれを選んでも共通で行う後始末(§4.3)。
    public func delete(issueId: Int64) throws {
        try db.exec(sql: "DELETE FROM stale_flag WHERE issue_id = ?", parameters: [.long(issueId)])
    }

    private func decode(_ row: [SQLValue]) throws -> StaleFlag {
        guard let issueId = row[0].longValue else {
            throw StaleFlagRepositoryError.unreadableColumn(name: "issue_id")
        }
        guard let reasonRaw = row[1].textValue,
              let reason = StaleReason(rawValue: reasonRaw) else {
            throw StaleFlagRepositoryError.unreadableColumn(name: "reason")
        }
        guard let evaluatedAtText = row[2].textValue,
              let evaluatedAt = timestamps.date(from: evaluatedAtText) else {
            throw StaleFlagRepositoryError.unreadableColumn(name: "evaluated_at")
        }
        return StaleFlag(issueId: issueId, reason: reason, evaluatedAt: evaluatedAt)
    }
}
