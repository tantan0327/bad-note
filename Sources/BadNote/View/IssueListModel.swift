import Foundation
import Observation
import SkipSQL

/// 課題一覧画面の状態(§7.4)。
///
/// 3 層を縦に並べたセクションリスト。層の移動は `FocusBoard` に任せ、ここは
/// 結果を保存して読み直すだけ。重点 3 枠の上限判定もすべて `FocusBoard` 側にある。
@Observable public final class IssueListModel {

    /// 一覧に出す状態。既定は `active` のみ。
    ///
    /// 未整理(`inbox`)を出すかどうかはここで決まる。整理の導線ができたら
    /// `[.inbox, .active]` に変える余地を残してある。
    public var statuses: [IssueStatus] = [IssueStatus.active]

    /// §7.4 上部の絞り込み行。**既定はフィルタなし** ——
    /// 絞ると、もう一方の種目が視界から消えて忘れられる。
    public var discipline: Discipline? = nil
    public var masteryLevel: MasteryLevel? = nil
    public var tagId: Int64? = nil
    /// 絞り込みに出すタグの候補
    public private(set) var availableTags: [Tag] = []

    /// 3 層を見出し込みで畳んだ並び(§7.4 長押しドラッグ用)。
    public private(set) var rows: [TierRow] = []

    public private(set) var focus: [Issue] = []
    public private(set) var next: [Issue] = []
    public private(set) var someday: [Issue] = []

    /// 入れ替え候補(現在の重点 3 件)。表示中は `isShowingSwap` が true。
    public private(set) var swapCandidates: [Issue] = []
    public var isShowingSwap = false
    public var errorText: String? = nil

    private var pendingPromotion: Issue? = nil
    private var database: SQLContext? = nil

    public init() {
    }

    /// 重点の残り枠(§7.4 の「今週の重点 3/3」)。
    public var focusCapacity: Int {
        return FocusBoard.focusCapacity
    }

    public func load() {
        do {
            let db = try context()
            let issues = IssueRepository(db: db)
            focus = try issues.fetch(tier: .focus, statuses: statuses, tagId: tagId,
                                     discipline: discipline, masteryLevel: masteryLevel)
            next = try issues.fetch(tier: .next, statuses: statuses, tagId: tagId,
                                    discipline: discipline, masteryLevel: masteryLevel)
            someday = try issues.fetch(tier: .someday, statuses: statuses, tagId: tagId,
                                       discipline: discipline, masteryLevel: masteryLevel)
            availableTags = try TagRepository(db: db).fetchAll()
            rows = TierLayout.rows(focus: focus, next: next, someday: someday)
            errorText = nil
        } catch {
            errorText = "課題の読み込みに失敗しました: \(error)"
        }
    }

    /// 絞り込みが 1 つでも掛かっているか(解除ボタンの出し分け)。
    public var isFiltering: Bool {
        return discipline != nil || masteryLevel != nil || tagId != nil
    }

    public func clearFilters() {
        discipline = nil
        masteryLevel = nil
        tagId = nil
        load()
    }

    public func selectDiscipline(_ value: Discipline?) {
        discipline = value
        load()
    }

    public func selectMasteryLevel(_ value: MasteryLevel?) {
        masteryLevel = value
        load()
    }

    public func selectTag(_ value: Int64?) {
        tagId = value
        load()
    }

    /// 絞り込み中のタグ名(表示用)。
    public func selectedTagName() -> String? {
        guard let tagId = tagId else {
            return nil
        }
        for tag in availableTags {
            if tag.id == tagId {
                return tag.name
            }
        }
        return nil
    }

    // MARK: - 層の移動

    /// 1 段上げる。重点が埋まっていれば入れ替え候補を出す(何も変更しない)。
    public func promote(_ issue: Issue) {
        guard let target = issue.tier.higher else {
            return
        }
        move(issue, to: target)
    }

    /// 1 段下げる。
    public func demote(_ issue: Issue) {
        guard let target = issue.tier.lower else {
            return
        }
        move(issue, to: target)
    }

    private func move(_ issue: Issue, to tier: Tier) {
        // 末尾に置く。範囲外の位置は FocusBoard 側で丸められる
        let result = FocusBoard.move(issue, to: tier, at: Int.max, in: allIssues())
        if let candidates = result.swapCandidates {
            pendingPromotion = issue
            swapCandidates = candidates
            isShowingSwap = true
            return
        }
        if let updated = result.updatedIssues {
            apply(updated)
        }
    }

    /// 長押しドラッグの結果を適用する(§7.4 層をまたぐ移動と層内の並び替え)。
    ///
    /// 移動先の逆算は `TierLayout`、実際の並べ替えは `FocusBoard` に任せる。
    public func moveRows(from offsets: [Int], to toOffset: Int) {
        guard let fromOffset = offsets.first else {
            return
        }
        guard let target = TierLayout.target(movingFrom: fromOffset, toOffset: toOffset, rows: rows) else {
            return
        }
        guard let issue = rows[fromOffset].issue else {
            return
        }
        let result = FocusBoard.move(issue, to: target.tier, at: target.index, in: allIssues())
        if let candidates = result.swapCandidates {
            pendingPromotion = issue
            swapCandidates = candidates
            isShowingSwap = true
            return
        }
        if let updated = result.updatedIssues {
            apply(updated)
        }
    }

    /// 層ごとの件数(見出しの表示用)。
    public func count(of tier: Tier) -> Int {
        switch tier {
        case .focus: return focus.count
        case .next: return next.count
        case .someday: return someday.count
        }
    }

    // MARK: - 入れ替え

    /// 「どれと入れ替えますか?」で選ばれた 1 件を next に降ろし、保留中の課題を重点に入れる。
    public func confirmSwap(with demoting: Issue) {
        guard let promoting = pendingPromotion else {
            cancelSwap()
            return
        }
        let updated = FocusBoard.swap(promoting: promoting, demoting: demoting, in: allIssues())
        apply(updated)
        cancelSwap()
    }

    public func cancelSwap() {
        pendingPromotion = nil
        swapCandidates = []
        isShowingSwap = false
    }

    // MARK: - 内部

    private func allIssues() -> [Issue] {
        var all: [Issue] = []
        all.append(contentsOf: focus)
        all.append(contentsOf: next)
        all.append(contentsOf: someday)
        return all
    }

    /// 変更があった課題だけ保存する。動いていない課題は `updated_at` を触らない。
    private func apply(_ updated: [Issue]) {
        do {
            let issues = IssueRepository(db: try context())
            for issue in updated {
                _ = try issues.update(issue)
            }
            errorText = nil
        } catch {
            errorText = "並び替えの保存に失敗しました: \(error)"
        }
        load()
    }

    private func context() throws -> SQLContext {
        if let database = database {
            return database
        }
        let opened = try AppDatabase.open()
        database = opened
        return opened
    }
}
