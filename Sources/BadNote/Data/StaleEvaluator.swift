import Foundation
import SkipSQL

/// stale の週次評価(§4.2 / §4.3 / §4.4)。
///
/// 判定そのものは純粋関数(`StaleEvaluation`)、実行するかどうかも純粋関数
/// (`StaleSchedule`)。ここはその 2 つに材料を渡し、結果を `stale_flag` に固定する係。
///
/// **自動で優先度を書き換えない。** 候補として提示するだけ(§4.3)。
public final class StaleEvaluator {
    private let db: SQLContext
    private let now: () -> Date
    private let calendar: Calendar

    public init(db: SQLContext, now: @escaping () -> Date = { Date() }, calendar: Calendar = Calendar.current) {
        self.db = db
        self.now = now
        self.calendar = calendar
    }

    /// 起動時に呼ぶ。実行条件を満たしたときだけ評価する。
    ///
    /// - 調整期(§4.4)は**評価自体をスキップ**する。大会直前に忘れていた課題を掘り返さない
    /// - 週 1 回だけ(§4.3)。毎日出すと無視されるようになる
    ///
    /// - Returns: 実際に評価したら true。
    @discardableResult
    public func evaluateIfNeeded() throws -> Bool {
        let today = now()
        if try isAdjustmentPeriod(asOf: today) {
            return false
        }
        let meta = AppMetaRepository(db: db)
        let shouldRun = StaleSchedule.shouldEvaluate(today: today,
                                                     lastEvaluatedAt: try meta.staleLastEvaluatedAt(),
                                                     reshuffleWeekday: try meta.reshuffleWeekday(),
                                                     calendar: calendar)
        if !shouldRun {
            return false
        }
        _ = try evaluate()
        return true
    }

    /// 実行条件を見ずに評価する。スナップショットを入れ替えて結果を返す。
    @discardableResult
    public func evaluate() throws -> [StaleFlag] {
        let evaluatedAt = now()
        let meta = AppMetaRepository(db: db)
        let thresholds = try meta.staleThresholds()
        let issues = IssueRepository(db: db)
        let practices = PracticeRepository(db: db)

        var flags: [StaleFlag] = []
        // §4.2 評価対象は status IN ('inbox','active')。focus は下の判定で外れる
        for issue in try issues.fetch(statuses: [.inbox, .active]) {
            let focusCount = try issues.focusSpanCount(issueId: issue.id)
            var practiceCount = 0
            if let leftAt = try issues.lastLeftFocusAt(issueId: issue.id) {
                practiceCount = try practices.countPractices(after: leftAt)
            }
            if let reason = StaleEvaluation.reason(status: issue.status,
                                                   tier: issue.tier,
                                                   createdAt: issue.createdAt,
                                                   focusCount: focusCount,
                                                   practiceCountSinceLeavingFocus: practiceCount,
                                                   updatedAt: issue.updatedAt,
                                                   asOf: evaluatedAt,
                                                   thresholds: thresholds) {
                flags.append(StaleFlag(issueId: issue.id, reason: reason, evaluatedAt: evaluatedAt))
            }
        }

        try StaleFlagRepository(db: db).replaceAll(flags)
        try meta.setStaleLastEvaluatedAt(evaluatedAt)
        return flags
    }

    /// §4.4 最も近い目標大会の 2 週間前に入っているか。
    private func isAdjustmentPeriod(asOf: Date) throws -> Bool {
        let competitions = CompetitionRepository(db: db)
        var targets: [Competition] = []
        for discipline in [Discipline.singles, Discipline.doubles] {
            if let target = try competitions.fetchTarget(discipline: discipline) {
                targets.append(target)
            }
        }
        return AdjustmentPeriod.isActive(targets: targets, asOf: calendar.startOfDay(for: asOf))
    }
}
