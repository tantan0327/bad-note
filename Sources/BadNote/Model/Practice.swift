import Foundation

/// 練習の種類(§7.2)。単一選択で、未選択も許す。
///
/// 休養日は記録しないので「休養」は作らない。
public enum PracticeKind: String, CaseIterable, Hashable {
    case whole
    case individual
    case game
    case strength
}

/// 手応え 3 段階。未入力は `FocusRecord.result` の nil(SQL では NULL)で表す。
///
/// 「×」「失敗」「未達」に相当する値は持たせない。
public enum FocusResult: String, CaseIterable, Hashable {
    case done
    case closer
    case next
}

/// 練習ログ(§6 `practice`)。1 回の練習の記録。
public struct Practice: Hashable, Identifiable {
    public var id: Int64
    /// 練習した日。§4.2 の比較のため UTC の ISO 8601 で保存する。
    public var practiceDate: Date
    public var minutes: Int
    /// 未選択なら nil(§7.2 全項目任意)
    public var kind: PracticeKind?
    public var createdAt: Date

    public init(id: Int64,
                practiceDate: Date,
                minutes: Int = 0,
                kind: PracticeKind? = nil,
                createdAt: Date) {
        self.id = id
        self.practiceDate = practiceDate
        self.minutes = minutes
        self.kind = kind
        self.createdAt = createdAt
    }
}

/// 保存済みの手応え(§6 `focus_record`)。練習ログ × 重点課題。
public struct FocusRecord: Hashable, Identifiable {
    public var id: Int64
    public var practiceId: Int64
    public var issueId: Int64
    /// nil は未入力。手応え未選択でも練習ログは保存できる(§7.2)。
    public var result: FocusResult?

    public init(id: Int64, practiceId: Int64, issueId: Int64, result: FocusResult? = nil) {
        self.id = id
        self.practiceId = practiceId
        self.issueId = issueId
        self.result = result
    }
}

/// 保存する手応えの入力。`FocusRecord` と違い id を持たない。
public struct FocusEntry: Hashable {
    public var issueId: Int64
    public var result: FocusResult?

    public init(issueId: Int64, result: FocusResult? = nil) {
        self.issueId = issueId
        self.result = result
    }
}
