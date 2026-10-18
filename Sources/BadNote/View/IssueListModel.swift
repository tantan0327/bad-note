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

    /// §7.4 検索語。**読み込み済みの一覧から絞る** —— 1 文字ごとに DB を引かない。
    /// 絞り込みや並び替えと同じく持ち越さない。
    public var searchText = ""

    /// §3.3 眺める順。**表示の切り替えだけで `sort_order` は書き換えない。**
    /// 絞り込みと同じく**持ち越さない** —— 起動のたびに手動へ戻る。
    /// 並びが変わったまま次に開くと、長押しドラッグが効かない理由が分からなくなる。
    public var sortOrder: IssueSortOrder = IssueSortOrder.manual

    /// 3 層を見出し込みで畳んだ並び(§7.4 長押しドラッグ用)。
    public private(set) var rows: [TierRow] = []

    /// 未整理(inbox)の課題(4.2)。練習ログで書いた 1 行はここに入る。
    /// 整理前で属性が付いていないので、絞り込みの対象にはしない。
    public private(set) var unorganized: [Issue] = []

    /// 層を動かした回数。触覚フィードバックのトリガー(5.2)。読み込みでは増えない
    public private(set) var moveCount = 0

    public private(set) var focus: [Issue] = []
    public private(set) var next: [Issue] = []
    public private(set) var someday: [Issue] = []

    /// 入れ替え候補(現在の重点 3 件)。表示中は `isShowingSwap` が true。
    public private(set) var swapCandidates: [Issue] = []
    public var isShowingSwap = false
    public var errorText: String? = nil

    private var pendingPromotion: Issue? = nil

    public init() {
    }

    /// 重点の残り枠(§7.4 の「今週の重点 3/3」)。
    /// 3 層に 1 件でもあるか。**並び替えの注記を出すかの判定**に使う ——
    /// 並べる行が無いのに「長押しで並び替え」とだけ書いてあっても試しようがない。
    public var hasTieredIssues: Bool {
        return !focus.isEmpty || !next.isEmpty || !someday.isEmpty
    }

    /// 3 層にも未整理にも 1 件も無い。
    ///
    /// **絞り込み中はこれを「使い始め」と呼んではいけない**(2026-10-18)。
    /// 絞り込みは SQL 側で効くので、該当 0 件でも中身が空になる。
    /// 初回の案内に化けると**絞り込み行ごと消えて解除できなくなる**。
    private var hasNothingLoaded: Bool {
        return !hasTieredIssues && unorganized.isEmpty
    }

    /// 使い始めの状態(課題が 1 件も無い)。絞り込んで 0 件になった場合は含めない。
    public var isEmpty: Bool {
        return hasNothingLoaded && !isFiltering
    }

    /// 絞り込んだ結果 0 件。**解除の導線を残したまま**こちらを出す。
    public var isFilteredToNothing: Bool {
        return hasNothingLoaded && isFiltering
    }

    public var focusCapacity: Int {
        return FocusBoard.focusCapacity
    }

    /// 畳んでいる層(2026-10-12)。**見えている件数を減らすため**で、
    /// 中身は消えない。畳んだ層にもドラッグの落下先は残る。
    public private(set) var collapsedTiers: [Tier] = [Tier]()
    /// 既定の畳み方を一度だけ決めたか。読み直すたびに畳み直すと、
    /// 本人が開いた層が勝手に閉じる。
    private var hasAppliedInitialCollapse = false

    /// 前回読んだときの層ごとの件数。**-1 は「まだ一度も読んでいない」。**
    /// 畳んだ層に課題が増えたかどうかの判定に使う(2026-10-18)。
    private var lastFocusCount = -1
    private var lastNextCount = -1
    private var lastSomedayCount = -1

    /// 長押しドラッグを使えるか。手動の並びで、かつ検索していないときだけ。
    ///
    /// 検索中は 3 層を畳んだ 1 本の並びが画面に出ていないので、
    /// 落とす先を逆算できない。
    public var allowsDrag: Bool {
        return sortOrder.allowsDrag && !isSearching
    }

    /// 検索語が効いているか。
    public var isSearching: Bool {
        return IssueSearch.isActive(searchText)
    }

    /// 検索の結果。**3 層 + 未整理をまとめて**、読み込み済みの一覧から絞る。
    ///
    /// 層をまたいで 1 本に並べるのは、探しているときに「どの層にいるか」を
    /// 先に思い出せないため。代わりに行へ居場所のバッジを添える。
    /// アーカイブ(定着した課題)は一覧に載っていないので対象外(別画面)。
    public var searchResults: [Issue] {
        var all: [Issue] = []
        all.append(contentsOf: focus)
        all.append(contentsOf: next)
        all.append(contentsOf: someday)
        all.append(contentsOf: unorganized)
        return IssueSearch.filtered(all, query: searchText)
    }

    public func load() {
        do {
            let db = try context()
            let issues = IssueRepository(db: db)
            // 並べ替えは**読んだ後**に表示だけ入れ替える(§3.3)。
            // SQL の ORDER BY を変えると、保存順と見えている順の区別が付かなくなる
            let fetchedFocus = try issues.fetch(tier: .focus, statuses: statuses, tagId: tagId,
                                                discipline: discipline, masteryLevel: masteryLevel)
            let fetchedNext = try issues.fetch(tier: .next, statuses: statuses, tagId: tagId,
                                               discipline: discipline, masteryLevel: masteryLevel)
            let fetchedSomeday = try issues.fetch(tier: .someday, statuses: statuses, tagId: tagId,
                                                  discipline: discipline, masteryLevel: masteryLevel)
            focus = IssueSort.sorted(fetchedFocus, by: sortOrder)
            next = IssueSort.sorted(fetchedNext, by: sortOrder)
            someday = IssueSort.sorted(fetchedSomeday, by: sortOrder)
            availableTags = try TagRepository(db: db).fetchAll()
            // 溜まっている「いつか」は最初から畳んでおく(1 度だけ判断する)
            if !hasAppliedInitialCollapse {
                collapsedTiers = TierLayout.initiallyCollapsed(somedayCount: someday.count)
                hasAppliedInitialCollapse = true
            }
            // **増えた層は開く**(2026-10-18)。課題を追加すると「いつか」に入るので、
            // 畳んだままだと件数が 1 増えるだけで行がどこにも出ない。
            // 「書いたのに見つからない」は未整理セクションを作ってまで潰した失敗。
            // ドラッグで畳んだ層に運び込んだときも同じ理由で開く
            expandTiersThatGrew()
            rows = TierLayout.rows(focus: focus, next: next, someday: someday,
                                   collapsed: collapsedTiers)
            unorganized = try issues.fetch(statuses: [IssueStatus.inbox])
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

    /// 前回より増えた層を開く。**初回の読み込みでは何もしない**
    /// (前回が無いので全層が「増えた」ことになり、既定の畳み方が無駄になる)。
    private func expandTiersThatGrew() {
        if lastFocusCount >= 0 {
            if focus.count > lastFocusCount {
                expand(Tier.focus)
            }
            if next.count > lastNextCount {
                expand(Tier.next)
            }
            if someday.count > lastSomedayCount {
                expand(Tier.someday)
            }
        }
        lastFocusCount = focus.count
        lastNextCount = next.count
        lastSomedayCount = someday.count
    }

    /// その層を開く。**保存した課題が畳まれた層に入って消えるのを防ぐ**(2026-10-18)。
    public func expand(_ tier: Tier) {
        var remaining: [Tier] = []
        for candidate in collapsedTiers {
            if candidate != tier {
                remaining.append(candidate)
            }
        }
        collapsedTiers = remaining
        rows = TierLayout.rows(focus: focus, next: next, someday: someday,
                               collapsed: collapsedTiers)
    }

    /// 層を畳む / 開く。
    public func toggleCollapse(_ tier: Tier) {
        var remaining: [Tier] = []
        var wasCollapsed = false
        for candidate in collapsedTiers {
            if candidate == tier {
                wasCollapsed = true
            } else {
                remaining.append(candidate)
            }
        }
        if !wasCollapsed {
            remaining.append(tier)
        }
        collapsedTiers = remaining
        rows = TierLayout.rows(focus: focus, next: next, someday: someday,
                               collapsed: collapsedTiers)
    }

    public func isCollapsed(_ tier: Tier) -> Bool {
        return TierLayout.isCollapsed(tier, in: collapsedTiers)
    }

    /// **いま見えている並びを保存順にする**(2026-10-12)。
    ///
    /// 押したあとは手動の並びに戻る —— そこから先はドラッグで微調整できる。
    /// これを置くまで、優先順に「見る」ことはできても「整理する」ことはできなかった。
    public func commitDisplayedOrder() {
        // **絞り込み中は焼き付けない**(2026-10-18)。見えている課題にだけ
        // 0,1,2… を振ると、隠れている課題の並びと衝突する。
        // 解除した瞬間、本人が一度も見ていない順番になり、取り消せない
        if isFiltering {
            errorText = "絞り込みを解除してから並びを保存してください"
            return
        }
        do {
            let issues = IssueRepository(db: try context())
            var changed: [Issue] = []
            changed.append(contentsOf: IssueOrderCommit.renumbered(focus))
            changed.append(contentsOf: IssueOrderCommit.renumbered(next))
            changed.append(contentsOf: IssueOrderCommit.renumbered(someday))
            for issue in changed {
                _ = try issues.update(issue)
            }
            sortOrder = IssueSortOrder.manual
            errorText = nil
        } catch {
            errorText = "並びの保存に失敗しました: \(error)"
        }
        load()
    }

    /// 眺める順を変える。**課題は 1 件も書き換わらない。**
    /// `setSortOrder` にすると Kotlin で `var sortOrder` の setter と衝突する。
    public func selectSortOrder(_ value: IssueSortOrder) {
        sortOrder = value
        load()
    }

    /// 並び替えのラベル(表示用)。**手動は既定なので名前を出さない**
    /// (絞り込みと同じ出し分け)。
    public func selectedSortName() -> String? {
        if sortOrder == IssueSortOrder.manual {
            return nil
        }
        return sortOrder.displayName
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
            moveCount += 1
            errorText = nil
        } catch {
            errorText = "並び替えの保存に失敗しました: \(error)"
        }
        load()
    }

    private func context() throws -> SQLContext {
        // 共有接続(6.3)。モデルごとに開くと database is locked を踏む
        return try AppDatabase.shared()
    }
}
