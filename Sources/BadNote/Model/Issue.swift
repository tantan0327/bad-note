import Foundation

/// 種目。多くの技術課題は種目を問わないため、既定は `both`(§3.5)。
public enum Discipline: String, CaseIterable, Hashable {
    case singles
    case doubles
    case both
}

/// 習熟度。不確実性の低い順に 4 段階(§3.2)。
///
/// raw value は `issue.mastery_level` にそのまま入る 1..4。
public enum MasteryLevel: Int, CaseIterable, Hashable {
    case solo = 1
    case drill = 2
    case pattern = 3
    case match = 4
}

/// 優先度の層(§3.3)。`focus` は 3 件までだが、上限はこの層より上のレイヤで扱う。
public enum Tier: String, CaseIterable, Hashable {
    case focus
    case next
    case someday

    /// 1 段上の層。`focus` が最上位なので、その上は無い。
    public var higher: Tier? {
        switch self {
        case .focus: return nil
        case .next: return Tier.focus
        case .someday: return Tier.next
        }
    }

    /// 1 段下の層。`someday` が最下位なので、その下は無い。
    public var lower: Tier? {
        switch self {
        case .focus: return Tier.next
        case .next: return Tier.someday
        case .someday: return nil
        }
    }
}

/// 課題の状態。`inbox` は未整理、`archived` は定着済み。
public enum IssueStatus: String, CaseIterable, Hashable {
    case inbox
    case active
    case archived
}

/// 課題(§3.1)。`issue` テーブルの 1 行に対応する。
///
/// `coachWords` は言われたことの原文で編集しない。`doneForm` は完了形の言い換えで、
/// 入力時には強制しないため未整理の間は nil。
public struct Issue: Hashable, Identifiable {
    /// 採番済みの主キー。`IssueRepository` が返す値にのみ現れる。
    public var id: Int64
    public var coachWords: String
    public var doneForm: String?
    public var coachName: String?
    public var discipline: Discipline
    public var masteryLevel: MasteryLevel
    public var tier: Tier
    /// 層の中の手動並び順。自動ソートは表示切り替えのみで、この値を書き換えない(§3.3)。
    public var sortOrder: Int
    /// 影響度 1..3(§3.4)
    public var impact: Int?
    /// 習得コスト 1..3(§3.4)
    public var cost: Int?
    public var status: IssueStatus
    /// 再浮上した回数。3 回以上で「よく戻ってくる課題」バッジ(§7.3)。
    public var resurfaceCount: Int
    public var lastFocusedAt: Date?
    public var createdAt: Date
    public var updatedAt: Date
    public var archivedAt: Date?

    public init(id: Int64,
                coachWords: String,
                doneForm: String? = nil,
                coachName: String? = nil,
                discipline: Discipline = .both,
                masteryLevel: MasteryLevel = .solo,
                tier: Tier = .someday,
                sortOrder: Int = 0,
                impact: Int? = nil,
                cost: Int? = nil,
                status: IssueStatus = .inbox,
                resurfaceCount: Int = 0,
                lastFocusedAt: Date? = nil,
                createdAt: Date,
                updatedAt: Date,
                archivedAt: Date? = nil) {
        self.id = id
        self.coachWords = coachWords
        self.doneForm = doneForm
        self.coachName = coachName
        self.discipline = discipline
        self.masteryLevel = masteryLevel
        self.tier = tier
        self.sortOrder = sortOrder
        self.impact = impact
        self.cost = cost
        self.status = status
        self.resurfaceCount = resurfaceCount
        self.lastFocusedAt = lastFocusedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.archivedAt = archivedAt
    }
}

extension Issue {
    /// UI の主表示。未整理で `doneForm` がまだ無ければ、コーチの言葉をそのまま出す(§3.1)。
    public var displayTitle: String {
        if let doneForm = doneForm, !doneForm.isEmpty {
            return doneForm
        }
        return coachWords
    }
}
