import XCTest
import Foundation
import SkipSQL
@testable import BadNote

/// stale の週次評価(§4.3)。
///
/// 判定結果を `stale_flag` に週次スナップショットとして保存し、次の評価まで固定する。
/// ホームの表示は `stale_flag` の単純な SELECT。
final class StaleEvaluatorTests: XCTestCase {

    /// 2023-11-20T00:00:00Z(月曜)
    private let monday = Date(timeIntervalSince1970: 1_700_438_400)

    private var clock = Date(timeIntervalSince1970: 1_700_438_400)

    private func makeDatabase() throws -> SQLContext {
        let db = SQLContext(configuration: .platform)
        try AppDatabase.prepare(db)
        return db
    }

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func makeEvaluator(_ db: SQLContext) -> StaleEvaluator {
        clock = monday
        return StaleEvaluator(db: db, now: { self.clock }, calendar: utcCalendar())
    }

    private func makeIssues(_ db: SQLContext) -> IssueRepository {
        return IssueRepository(db: db, now: { self.clock })
    }

    private func day(_ offset: Double) -> Date {
        return Date(timeIntervalSince1970: 1_700_438_400.0 + offset * 86_400.0)
    }

    /// 30 日前に作られ、一度も重点に入っていない課題。
    private func makeStaleIssue(_ db: SQLContext, coachWords: String = "A") throws -> Issue {
        let old = day(-30)
        let issues = IssueRepository(db: db, now: { old })
        return try issues.create(coachWords: coachWords)
    }

    // MARK: - 評価

    func testEvaluateFlagsNeverFocusedIssue() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let evaluator = makeEvaluator(db)
        let issue = try makeStaleIssue(db)

        let flags = try evaluator.evaluate()

        XCTAssertEqual([issue.id], flags.map { $0.issueId })
    }

    func testEvaluateStoresReason() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let evaluator = makeEvaluator(db)
        _ = try makeStaleIssue(db)

        let flag = try XCTUnwrap(try evaluator.evaluate().first)

        XCTAssertEqual(StaleReason.neverFocused, flag.reason)
    }

    func testEvaluateStoresEvaluatedAt() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let evaluator = makeEvaluator(db)
        _ = try makeStaleIssue(db)

        let flag = try XCTUnwrap(try evaluator.evaluate().first)

        XCTAssertEqual(monday, flag.evaluatedAt)
    }

    /// §4.2 現に focus にある課題は対象外。
    func testEvaluateSkipsFocusedIssues() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let evaluator = makeEvaluator(db)
        let issue = try makeStaleIssue(db)
        var edited = issue
        edited.tier = .focus
        _ = try makeIssues(db).update(edited)

        let flags = try evaluator.evaluate()

        XCTAssertEqual(0, flags.count)
    }

    /// archived は対象外。
    func testEvaluateSkipsArchivedIssues() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let evaluator = makeEvaluator(db)
        let issue = try makeStaleIssue(db)
        var edited = issue
        edited.status = .archived
        _ = try makeIssues(db).update(edited)

        let flags = try evaluator.evaluate()

        XCTAssertEqual(0, flags.count)
    }

    func testEvaluateSkipsRecentIssues() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let evaluator = makeEvaluator(db)
        _ = try makeIssues(db).create(coachWords: "新しい課題")

        let flags = try evaluator.evaluate()

        XCTAssertEqual(0, flags.count)
    }

    /// §4.3 評価実行時は stale_flag を全削除してから再 INSERT する。
    func testEvaluateReplacesPreviousSnapshot() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let evaluator = makeEvaluator(db)
        let issue = try makeStaleIssue(db)
        _ = try evaluator.evaluate()

        // 重点に入れて対象外にしてから、もう一度評価する
        // XCTUnwrap の戻り値からは Skip が型を辿れないので明示する
        var edited: Issue = try XCTUnwrap(try makeIssues(db).fetch(id: issue.id))
        edited.tier = Tier.focus
        _ = try makeIssues(db).update(edited)
        let flags = try evaluator.evaluate()

        XCTAssertEqual(0, flags.count, "前回のフラグが残らないこと")
        XCTAssertEqual(0, try StaleFlagRepository(db: db).fetchAll().count)
    }

    func testEvaluateRecordsLastEvaluatedAt() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let evaluator = makeEvaluator(db)

        _ = try evaluator.evaluate()

        XCTAssertEqual(monday, try AppMetaRepository(db: db).staleLastEvaluatedAt())
    }

    /// 閾値は app_meta から読む(§4.2)。
    func testEvaluateUsesThresholdsFromAppMeta() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let evaluator = makeEvaluator(db)
        // 10 日前の課題。既定の 21 日では該当しない
        let old = day(-10)
        _ = try IssueRepository(db: db, now: { old }).create(coachWords: "A")
        try AppMetaRepository(db: db).setStaleThresholds(StaleThresholds(days: 7, practiceCount: 6))

        let flags = try evaluator.evaluate()

        XCTAssertEqual(1, flags.count)
    }

    // MARK: - 実行ゲート(§4.3)

    /// 一度も評価していなければ実行する。
    func testEvaluateIfNeededRunsOnFirstLaunch() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let evaluator = makeEvaluator(db)
        _ = try makeStaleIssue(db)

        let didRun = try evaluator.evaluateIfNeeded()

        XCTAssertTrue(didRun)
    }

    /// 同じ日に 2 回目は走らせない。
    func testEvaluateIfNeededDoesNotRunTwiceInADay() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let evaluator = makeEvaluator(db)
        _ = try evaluator.evaluateIfNeeded()

        let didRun = try evaluator.evaluateIfNeeded()

        XCTAssertFalse(didRun)
    }

    // MARK: - 調整期(§4.4)

    /// 調整期は評価自体をスキップする。大会直前に掘り返さない。
    func testEvaluateIfNeededSkipsDuringAdjustmentPeriod() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let evaluator = makeEvaluator(db)
        _ = try makeStaleIssue(db)
        // 5 日後が目標大会 → 調整期
        _ = try CompetitionRepository(db: db, now: { self.clock })
            .create(name: "県大会", eventDate: day(5), entries: [CompetitionEntry(discipline: .singles, isTarget: true)])

        let didRun = try evaluator.evaluateIfNeeded()

        XCTAssertFalse(didRun)
        XCTAssertEqual(0, try StaleFlagRepository(db: db).fetchAll().count)
    }

    func testEvaluateIfNeededRunsOutsideAdjustmentPeriod() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let evaluator = makeEvaluator(db)
        _ = try makeStaleIssue(db)
        _ = try CompetitionRepository(db: db, now: { self.clock })
            .create(name: "県大会", eventDate: day(60), entries: [CompetitionEntry(discipline: .singles, isTarget: true)])

        let didRun = try evaluator.evaluateIfNeeded()

        XCTAssertTrue(didRun)
    }

    // MARK: - 3 択の処理(§4.3)

    func testDismissRemovesFlagOnly() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let evaluator = makeEvaluator(db)
        let issue = try makeStaleIssue(db)
        _ = try evaluator.evaluate()

        try StaleFlagRepository(db: db).delete(issueId: issue.id)

        XCTAssertEqual(0, try StaleFlagRepository(db: db).fetchAll().count)
        XCTAssertNotNil(try makeIssues(db).fetch(id: issue.id), "課題そのものは残る")
    }

    func testFlagIsRemovedWhenIssueIsDeleted() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let evaluator = makeEvaluator(db)
        let issue = try makeStaleIssue(db)
        _ = try evaluator.evaluate()

        try makeIssues(db).delete(id: issue.id)

        XCTAssertEqual(0, try StaleFlagRepository(db: db).fetchAll().count)
    }
}
