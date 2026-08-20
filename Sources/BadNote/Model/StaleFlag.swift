import Foundation

/// stale の週次スナップショット 1 件(§6 `stale_flag`)。
///
/// 判定結果はここに固定され、次の評価まで変わらない。ホームの表示は
/// このテーブルの単純な SELECT で済む(§4.3)。
public struct StaleFlag: Hashable, Identifiable {
    public var issueId: Int64
    public var reason: StaleReason
    public var evaluatedAt: Date

    public var id: Int64 {
        return issueId
    }

    public init(issueId: Int64, reason: StaleReason, evaluatedAt: Date) {
        self.issueId = issueId
        self.reason = reason
        self.evaluatedAt = evaluatedAt
    }
}
