import Foundation
import Observation
import SkipSQL

/// ホーム画面の状態(§7.1)。
///
/// 判定は既存の純粋関数に任せ、ここは読み込みと組み立てだけを行う。
/// - 主数値の切り替え: `HomeEmphasis`(§5.1、種目ごとに独立)
/// - 残り練習回数: `PracticePlan`(§5.2。登録された練習予定日を数える)
/// - 調整期: `AdjustmentPeriod`(§4.4、全体で 1 つ)
/// - 今月の範囲: `MonthRange`
///
/// **課題の総数と未整理件数は持たない**(§5.3 やらないこと)。
@Observable public final class HomeModel {

    /// 種目ごとのカウントダウン(§7.1)。
    public struct Countdown: Identifiable, Hashable {
        public var discipline: Discipline
        public var competition: Competition
        public var remainingDays: Int
        /// 推定できないときは nil。0 回とは意味が違う(§5.2)。
        public var remainingPractices: Int?
        public var emphasis: HomeEmphasis

        public var id: String {
            return discipline.rawValue
        }
    }

    /// しばらく触れていない課題 1 件(§4.3)。理由を添えて出す。
    public struct StaleItem: Identifiable, Hashable {
        public var issue: Issue
        public var reason: StaleReason

        public var id: Int64 {
            return issue.id
        }
    }

    /// 今週の重点カード(§7.1)。
    public struct FocusCard: Identifiable, Hashable {
        public var issue: Issue
        /// 直近の手応え。まだ記録が無ければ nil。
        public var latestResult: FocusResult?

        public var id: Int64 {
            return issue.id
        }
    }

    public private(set) var vision = Vision()
    public private(set) var countdowns: [Countdown] = []
    public private(set) var focusCards: [FocusCard] = []
    /// 今月の練習時間(分)
    public private(set) var monthMinutes = 0
    /// 通算の練習時間(分)。積み上げカードの主数字(2.1)。減らない数字
    public private(set) var lifetimeMinutes = 0
    /// 今月のレベルアップ回数
    public private(set) var monthLevelUps = 0
    /// 目標大会が 1 つも無い(§7.1 大会未登録の扱い)
    public private(set) var hasTargetCompetition = false
    /// 目標大会が遠いときに添える手前の大会(§7.5)。無ければ nil。
    public private(set) var nextCompetition: Competition? = nil
    public private(set) var nextCompetitionDays = 0
    /// 目標大会が無いときに「これを目標にしませんか」と差し出す大会(§7.5)。
    /// `nextCompetition` とは排他 —— 同じ大会をホームに 2 回出さない。
    public private(set) var targetCandidate: Competition? = nil
    /// 調整期(§4.4)。stale の提示を止める判断に使う。
    public private(set) var isAdjustmentPeriod = false
    /// 練習予定日が 1 日でも登録されているか(§5.2)。
    /// **未設定なら残り回数を出さず、設定へ誘導する** —— 根拠のない数字を出さない。
    public private(set) var hasPracticePlan = false

    /// めざす姿を書くよう促すか(§7.1)。初回は促さず、数回使った後に 1 度だけ。
    public private(set) var isPromptingVision = false

    /// ほんとうの初回(課題も練習も無い)か(4.1)。
    /// このときだけ重点の空きが「課題を書く」への誘導になる。
    /// めざす姿は促さない(§7.1 の決めごとのまま)。
    public private(set) var isJustStarting = false

    /// しばらく触れていない課題(§4.3)。`stale_flag` の単純な読み出し。
    public private(set) var staleItems: [StaleItem] = []
    /// 重点が埋まっているときの入れ替え候補(§7.4 のフローへ回す)。
    public private(set) var swapCandidates: [Issue] = []
    public var isShowingSwap = false
    private var pendingPromotion: Issue? = nil

    public var errorText: String? = nil


    public init() {
    }

    public func load(now: Date = Date()) {
        do {
            let db = try context()
            // 日付の境界は「今日の 0 時」で揃える。当日の大会を当日いっぱい残す
            let today = Calendar.current.startOfDay(for: now)

            vision = try VisionRepository(db: db).fetch()
            try loadVisionPrompt(db: db)
            try loadFirstSteps(db: db)
            try loadCountdowns(db: db, today: today)
            try loadFocusCards(db: db)
            try loadBuildUp(db: db, now: now)
            // §4.3 起動時のゲート。走るのは週 1 回、調整期はスキップ
            try StaleEvaluator(db: db, now: { now }).evaluateIfNeeded()
            try loadStaleItems(db: db)
            // §8 通知の予定を入れ直す。組み立ては同じ接続、登録だけ非同期
            let planned = try NotificationService(db: db).plannedNotifications(now: now)
            Task {
                await NotificationService.apply(planned)
            }
            errorText = nil
        } catch {
            errorText = "ホームの読み込みに失敗しました: \(error)"
        }
    }

    // MARK: - カウントダウン

    private func loadCountdowns(db: SQLContext, today: Date) throws {
        let competitions = CompetitionRepository(db: db)

        // 終わった大会は目標から下ろす(§7.5)。残したままだと目標が埋まっている扱いになり、
        // カウントダウンも次の目標大会の促しも出ないまま止まる
        try competitions.clearFinishedTargets(asOf: today)

        // §5.2 残り練習回数は**登録された練習予定日を数える**(推定しない)
        var planDays: [Date] = []
        for planDay in try PracticePlanRepository(db: db).fetchUpcoming(asOf: today) {
            planDays.append(planDay.date)
        }
        hasPracticePlan = !planDays.isEmpty

        var targets: [Competition] = []
        var cards: [Countdown] = []
        for discipline in [Discipline.singles, Discipline.doubles] {
            guard let target = try competitions.fetchTarget(discipline: discipline) else {
                continue
            }
            targets.append(target)
            // 過ぎた大会はカウントダウンに出さない
            let remainingDays = HomeModel.days(from: today, to: target.eventDate)
            if remainingDays < 0 {
                continue
            }
            cards.append(Countdown(discipline: discipline,
                                   competition: target,
                                   remainingDays: remainingDays,
                                   remainingPractices: PracticePlan.remainingCount(planDays: planDays,
                                                                                   eventDate: target.eventDate,
                                                                                   asOf: today),
                                   emphasis: HomeEmphasis.forEvent(target.eventDate, asOf: today)))
        }

        // 近いほうを上に(§7.1)
        countdowns = HomeModel.sortedByNearest(cards)
        hasTargetCompetition = !targets.isEmpty
        isAdjustmentPeriod = AdjustmentPeriod.isActive(targets: targets, asOf: today)

        try loadNextCompetition(competitions: competitions, targets: targets, today: today)
    }

    /// 手前の大会を 1 件選び、2 つの用途に振り分ける(§7.5)。
    ///
    /// - **目標大会が無いとき** → `targetCandidate`。
    ///   カウントダウン欄の「目標の大会が決まっていません」から目標に指定する相手にする。
    ///   「次の大会」としては出さない —— 「手前」は目標があってはじめて意味を持つし、
    ///   同じ大会がホームに 2 回出てしまう(2026-08-25)
    /// - **目標大会が 8 週間より先のとき** → `nextCompetition`(「次の大会」セクション)
    /// - **目標大会が 8 週間以内のとき** → どちらにも出さない。
    ///   そこに集中する時期に別の大会を足すと焦点がぼける(§5.1 の裏返し)
    private func loadNextCompetition(competitions: CompetitionRepository,
                                     targets: [Competition],
                                     today: Date) throws {
        nextCompetition = nil
        nextCompetitionDays = 0
        targetCandidate = nil

        var targetIds: [Int64] = []
        for target in targets {
            targetIds.append(target.id)
        }
        let upcoming = try competitions.fetchUpcoming(asOf: today)
        guard let picked = NextCompetition.pick(upcoming: upcoming, targetIds: targetIds, asOf: today) else {
            return
        }

        if targets.isEmpty {
            targetCandidate = picked
            return
        }
        for card in countdowns {
            if card.emphasis == HomeEmphasis.countdown {
                return
            }
        }
        nextCompetition = picked
        nextCompetitionDays = HomeModel.days(from: today, to: picked.eventDate)
    }

    // MARK: - 今週の重点

    private func loadFocusCards(db: SQLContext) throws {
        let issues = try IssueRepository(db: db).fetch(tier: .focus, statuses: [.active])
        let practices = PracticeRepository(db: db)
        var cards: [FocusCard] = []
        for issue in issues {
            let history = try practices.fetchFocusResults(issueId: issue.id)
            cards.append(FocusCard(issue: issue, latestResult: history.first ?? nil))
        }
        focusCards = cards
    }

    // MARK: - めざす姿の促し(§7.1)

    /// 促すかどうかを決め、**出すと決めた時点で「促し済み」にする。**
    ///
    /// 無視されたものを毎回蒸し返さないため。仕様の「1 度だけ」をこの形で守る。
    private func loadVisionPrompt(db: SQLContext) throws {
        let meta = AppMetaRepository(db: db)
        let shouldPrompt = VisionPrompt.shouldPrompt(vision: vision,
                                                     practiceCount: try PracticeRepository(db: db).count(),
                                                     alreadyPrompted: try meta.isVisionPromptShown())
        if shouldPrompt {
            try meta.markVisionPromptShown()
        }
        isPromptingVision = shouldPrompt
    }

    /// 促しを閉じる(表示は 1 度きりなので、記録済みのフラグはそのまま)。
    public func dismissVisionPrompt() {
        isPromptingVision = false
    }

    // MARK: - しばらく触れていない課題(§4.3)

    /// ホームの表示は `stale_flag` の単純な SELECT。判定はしない。
    private func loadStaleItems(db: SQLContext) throws {
        // 調整期はセクションごと隠す(§4.4)
        if isAdjustmentPeriod {
            staleItems = []
            return
        }
        let issues = IssueRepository(db: db)
        var items: [StaleItem] = []
        for flag in try StaleFlagRepository(db: db).fetchAll() {
            guard let issue = try issues.fetch(id: flag.issueId) else {
                continue
            }
            items.append(StaleItem(issue: issue, reason: flag.reason))
        }
        staleItems = items
    }

    /// 3 択その 1: 今週の重点にする。
    ///
    /// 空きがあれば `focus` に上げ、再浮上回数を 1 増やしてフラグを消す。
    /// 埋まっていれば入れ替えフローへ回す(§7.4)。
    public func focusOnStaleIssue(_ item: StaleItem) {
        do {
            let db = try context()
            let issues = IssueRepository(db: db)
            let board = try issues.fetch(statuses: [.inbox, .active])
            let result = FocusBoard.move(item.issue, to: .focus, at: Int.max, in: board)
            if let candidates = result.swapCandidates {
                pendingPromotion = item.issue
                swapCandidates = candidates
                isShowingSwap = true
                return
            }
            if let updated = result.updatedIssues {
                try applyPromotion(updated, promoted: item.issue, issues: issues)
            }
            try StaleFlagRepository(db: db).delete(issueId: item.issue.id)
            load()
        } catch {
            errorText = "重点への移動に失敗しました: \(error)"
        }
    }

    /// 入れ替えを確定して重点に入れる。
    public func confirmSwap(with demoting: Issue) {
        guard let promoting = pendingPromotion else {
            cancelSwap()
            return
        }
        do {
            let db = try context()
            let issues = IssueRepository(db: db)
            let board = try issues.fetch(statuses: [.inbox, .active])
            let updated = FocusBoard.swap(promoting: promoting, demoting: demoting, in: board)
            try applyPromotion(updated, promoted: promoting, issues: issues)
            try StaleFlagRepository(db: db).delete(issueId: promoting.id)
            cancelSwap()
            load()
        } catch {
            errorText = "入れ替えに失敗しました: \(error)"
        }
    }

    public func cancelSwap() {
        pendingPromotion = nil
        swapCandidates = []
        isShowingSwap = false
    }

    /// 3 択その 2: まだいい。フラグを消すだけ(翌週また該当し得る。これは許容)。
    public func postponeStaleIssue(_ item: StaleItem) {
        do {
            try StaleFlagRepository(db: try context()).delete(issueId: item.issue.id)
            load()
        } catch {
            errorText = "更新に失敗しました: \(error)"
        }
    }

    /// 3 択その 3: もう不要。アーカイブしてフラグを消す。
    public func archiveStaleIssue(_ item: StaleItem) {
        do {
            let db = try context()
            var issue = item.issue
            issue.status = .archived
            issue.archivedAt = Date()
            _ = try IssueRepository(db: db).update(issue)
            try StaleFlagRepository(db: db).delete(issueId: item.issue.id)
            load()
        } catch {
            errorText = "アーカイブに失敗しました: \(error)"
        }
    }

    /// 層の変更を保存し、重点に上がった課題の再浮上回数を 1 増やす(§4.3)。
    private func applyPromotion(_ updated: [Issue], promoted: Issue, issues: IssueRepository) throws {
        for issue in updated {
            var target = issue
            if target.id == promoted.id {
                target.resurfaceCount += 1
                // 未整理のまま重点に上げると、ホームも課題一覧も active しか
                // 出さないので行き場を失う。重点にする判断自体が整理なので active に
                if target.status == .inbox {
                    target.status = .active
                }
            }
            _ = try issues.update(target)
        }
    }

    // MARK: - 最初の 1 歩(4.1)

    /// 課題(inbox / active)も練習ログも無ければ、まだ何も始まっていない。
    /// どちらかが 1 つでもできたら二度と出ない(状態から導くので、フラグは持たない)。
    private func loadFirstSteps(db: SQLContext) throws {
        let issues = try IssueRepository(db: db).fetch(statuses: [IssueStatus.inbox, IssueStatus.active])
        let practiceCount = try PracticeRepository(db: db).count()
        isJustStarting = issues.isEmpty && practiceCount == 0
    }

    // MARK: - 積み上げ

    private func loadBuildUp(db: SQLContext, now: Date) throws {
        let month = MonthRange.containing(now)
        // 家トレも合算した累計(§10.3)。PracticeRepository 直では家トレの分が落ちる
        let stats = StatsRepository(db: db)
        monthMinutes = try stats.totalMinutes(from: month.start, to: month.end)
        lifetimeMinutes = try stats.lifetimeMinutes()
        monthLevelUps = try IssueRepository(db: db).countLevelUps(from: month.start, to: month.end)
    }

    // MARK: - 内部

    private static func days(from: Date, to: Date) -> Int {
        return Int(to.timeIntervalSince(from) / 86_400.0)
    }

    private static func sortedByNearest(_ cards: [Countdown]) -> [Countdown] {
        let ordered = cards.sorted(by: { first, second in
            return first.remainingDays < second.remainingDays
        })
        // Skip では sorted の戻り値が変更不可のため写す
        var result: [Countdown] = []
        result.append(contentsOf: ordered)
        return result
    }

    private func context() throws -> SQLContext {
        // 共有接続(6.3)。モデルごとに開くと database is locked を踏む
        return try AppDatabase.shared()
    }
}
