import Foundation

/// 種目。多くの技術課題は種目を問わないため、既定は `both`(§3.5)。
public enum Discipline: String, CaseIterable, Hashable, Sendable {
    case singles
    case doubles
    case both
}

/// 習熟度。不確実性の低い順に 4 段階(§3.2)。
///
/// raw value は `issue.mastery_level` にそのまま入る 1..4。
public enum MasteryLevel: Int, CaseIterable, Hashable, Sendable {
    case solo = 1
    case drill = 2
    case pattern = 3
    case match = 4

    /// 1 つ下のレベル。**Lv.1 の下は無いので Lv.1 のまま**(§7.3 ゼロに戻さない)。
    ///
    /// 再浮上させるときの再開レベルに使う。
    public var oneStepDown: MasteryLevel {
        return MasteryLevel(rawValue: rawValue - 1) ?? MasteryLevel.solo
    }

    /// 克服した(定着確認へ)に進めるか。**Lv.4(試合で出せる)のときだけ**(§7.3)。
    ///
    /// 素振りでできるだけの課題を「克服した」とは呼べない。
    public var canOvercome: Bool {
        return self == MasteryLevel.match
    }
}

/// 優先度の層(§3.3)。`focus` は 3 件までだが、上限はこの層より上のレイヤで扱う。
public enum Tier: String, CaseIterable, Hashable, Sendable {
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

/// 課題の状態。
///
/// - `inbox` 未整理
/// - `active` 一覧に並んでいる
/// - `archived` **定着した**(克服の証。積み上げの数字に入る)
/// - `shelved` **見送った**(もうやらないと決めた。積み上げには入らない)
///
/// **`archived` と `shelved` を分けてあるのが肝。** ひとつにすると、
/// 興味を失った課題を外すたびに「定着した課題」が増えて、達成の数字が嘘になる。
/// 嘘になるくらいならと外さなくなり、課題が減らなくなる(2026-10-11)。
///
/// `status` は CHECK の無い TEXT 列なので、値を足すのに移行は要らない。
public enum IssueStatus: String, CaseIterable, Hashable, Sendable {
    case inbox
    case active
    case archived
    case shelved
}

/// 課題(§3.1)。`issue` テーブルの 1 行に対応する。
///
/// `coachWords` はもとの言葉(原文)で編集しない。`doneForm` は完了形の言い換えで、
/// 入力時には強制しないため未整理の間は nil。
public struct Issue: Hashable, Identifiable, Sendable {
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
    /// このレベルでのレベルアップ提案を断ったときの `masteryLevel`(§3.2 の「1 度だけ提案」)。
    /// レベルが変われば再び提案してよい。
    public var levelUpDeclinedLevel: Int?
    /// 「1 つ戻す」提案を断ったレベル(§3.2)。**昇格の記録と分けてある** ——
    /// 上げるのを断ったことが、戻す提案まで黙らせるのは誤り
    public var stepDownDeclinedLevel: Int?
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
                levelUpDeclinedLevel: Int? = nil,
                stepDownDeclinedLevel: Int? = nil,
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
        self.levelUpDeclinedLevel = levelUpDeclinedLevel
        self.stepDownDeclinedLevel = stepDownDeclinedLevel
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.archivedAt = archivedAt
    }
}

extension Issue {
    /// UI の主表示。未整理で `doneForm` がまだ無ければ、原文をそのまま出す(§3.1)。
    public var displayTitle: String {
        if let doneForm = doneForm, !doneForm.isEmpty {
            return doneForm
        }
        return coachWords
    }

    /// **原文とは違う言い換えを持っているか。**
    ///
    /// 課題詳細で「もとの言葉」を引用するかの判定に使う(2026-08-26)。
    /// 持っていなければ `displayTitle` が原文そのものなので、引用すると
    /// **同じ文が画面に 2 度出る**。追加画面を 1 欄にしてから、
    /// 言い換えを持たない課題のほうが多い。
    public var hasDoneForm: Bool {
        guard let doneForm = doneForm, !doneForm.isEmpty else {
            return false
        }
        return doneForm != coachWords
    }
}

extension Issue {
    /// 「よく戻ってくる課題」バッジを出す再浮上回数(§7.3)。
    public static let frequentResurfaceThreshold = 3

    /// 何度も戻ってくる課題。弱点の本質を示す情報として提示する(§7.3)。
    public var isFrequentlyResurfacing: Bool {
        return resurfaceCount >= Issue.frequentResurfaceThreshold
    }
}
