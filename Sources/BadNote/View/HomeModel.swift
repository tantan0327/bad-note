import Foundation
import Observation
import SkipSQL

/// ホーム画面の状態(§7.1)。
///
/// 判定は既存の純粋関数に任せ、ここは読み込みと組み立てだけを行う。
/// - 主数値の切り替え: `HomeEmphasis`(§5.1、種目ごとに独立)
/// - 残り練習回数: `PracticeForecast`(§5.2)
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
    /// 今月のレベルアップ回数
    public private(set) var monthLevelUps = 0
    /// 目標大会が 1 つも無い(§7.1 大会未登録の扱い)
    public private(set) var hasTargetCompetition = false
    /// 調整期(§4.4)。stale の提示を止める判断に使う。
    public private(set) var isAdjustmentPeriod = false

    public var errorText: String? = nil

    private var database: SQLContext? = nil

    public init() {
    }

    public func load(now: Date = Date()) {
        do {
            let db = try context()
            // 日付の境界は「今日の 0 時」で揃える。当日の大会を当日いっぱい残す
            let today = Calendar.current.startOfDay(for: now)

            vision = try VisionRepository(db: db).fetch()
            try loadCountdowns(db: db, today: today)
            try loadFocusCards(db: db)
            try loadBuildUp(db: db, now: now)
            errorText = nil
        } catch {
            errorText = "ホームの読み込みに失敗しました: \(error)"
        }
    }

    // MARK: - カウントダウン

    private func loadCountdowns(db: SQLContext, today: Date) throws {
        let competitions = CompetitionRepository(db: db)
        let practices = PracticeRepository(db: db)

        var practiceDates: [Date] = []
        for practice in try practices.fetchAll() {
            practiceDates.append(practice.practiceDate)
        }

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
                                   remainingPractices: PracticeForecast.remainingPracticeCount(practiceDates: practiceDates,
                                                                                               eventDate: target.eventDate,
                                                                                               asOf: today),
                                   emphasis: HomeEmphasis.forEvent(target.eventDate, asOf: today)))
        }

        // 近いほうを上に(§7.1)
        countdowns = HomeModel.sortedByNearest(cards)
        hasTargetCompetition = !targets.isEmpty
        isAdjustmentPeriod = AdjustmentPeriod.isActive(targets: targets, asOf: today)
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

    // MARK: - 積み上げ

    private func loadBuildUp(db: SQLContext, now: Date) throws {
        let month = MonthRange.containing(now)
        monthMinutes = try PracticeRepository(db: db).totalMinutes(from: month.start, to: month.end)
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
        if let database = database {
            return database
        }
        let opened = try AppDatabase.open()
        database = opened
        return opened
    }
}
