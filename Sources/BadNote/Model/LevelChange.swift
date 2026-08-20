import Foundation

/// 習熟度の変更履歴(§6 `level_change`)。
///
/// §7.3 の「レベルアップ回数」と §5.1 の積み上げ表示の元。
/// 下げた記録も残す —— 上げ下げの両方が分かって初めて進み方が読める。
public struct LevelChange: Hashable, Identifiable {
    public var id: Int64
    public var issueId: Int64
    public var fromLevel: MasteryLevel
    public var toLevel: MasteryLevel
    public var createdAt: Date

    public init(id: Int64, issueId: Int64, fromLevel: MasteryLevel, toLevel: MasteryLevel, createdAt: Date) {
        self.id = id
        self.issueId = issueId
        self.fromLevel = fromLevel
        self.toLevel = toLevel
        self.createdAt = createdAt
    }

    /// 数える対象は上がった分だけ(§5.1 レベルアップ回数)。
    public var isLevelUp: Bool {
        return toLevel.rawValue > fromLevel.rawValue
    }
}
