#if DEBUG
import XCTest
import Foundation
import SkipSQL
@testable import BadNote

/// ストアのスクリーンショット用のデモデータ(§1.4)。
///
/// **撮りたい画面がちゃんと埋まるか**をここで固定する。
/// 実機に入れてから「カウントダウンが出ない」「棚卸しが誘ってこない」と
/// 気づくと、撮影のたびに作り直すことになる。
///
/// `#if DEBUG` 同士なので Android 側には存在しない(本体も同じ)。
final class DemoDataTests: XCTestCase {

    /// 2026-06-15(日)。曜日に依存する判定があるので固定日で見る。
    private let today = Date(timeIntervalSince1970: 1_781_481_600.0)

    private func makeDatabase() throws -> SQLContext {
        let db = SQLContext(configuration: .platform)
        try AppDatabase.prepare(db)
        return db
    }

    private func seeded() throws -> SQLContext {
        let db = try makeDatabase()
        try DemoData.seed(db: db, now: today)
        return db
    }

    // MARK: - ホームが埋まる

    func testVisionIsWritten() throws {
        let db = try seeded()
        defer { try? db.close() }

        XCTAssertFalse(try VisionRepository(db: db).fetch().isEmpty)
    }

    /// カウントダウンの出る目標大会がある。**2 週間より先**にしてあること ——
    /// 近すぎると調整期に入って、しばらく触れていない課題が出なくなる(§4.4)。
    func testTargetCompetitionIsFarEnoughAhead() throws {
        let db = try seeded()
        defer { try? db.close() }

        let target = try CompetitionRepository(db: db).fetchTarget(discipline: Discipline.singles)
        var found: Competition = try XCTUnwrap(target)
        let days = Calendar.current.dateComponents([Calendar.Component.day],
                                                   from: today,
                                                   to: found.eventDate).day ?? 0
        XCTAssertTrue(days > 14, "目標大会が近すぎると調整期に入る: \(days) 日")
    }

    // MARK: - 課題一覧の 3 層が埋まる

    func testThreeTiersAreFilled() throws {
        let db = try seeded()
        defer { try? db.close() }
        let issues = IssueRepository(db: db)

        XCTAssertEqual(3, try issues.fetch(tier: .focus, statuses: [IssueStatus.active]).count)
        XCTAssertEqual(5, try issues.fetch(tier: .next, statuses: [IssueStatus.active]).count)
        XCTAssertEqual(12, try issues.fetch(tier: .someday, statuses: [IssueStatus.active]).count)
    }

    /// 未整理のセクションが出る。
    func testInboxHasIssues() throws {
        let db = try seeded()
        defer { try? db.close() }

        XCTAssertEqual(2, try IssueRepository(db: db).fetch(statuses: [IssueStatus.inbox]).count)
    }

    /// 積み上げの「定着した課題」が 0 のままだと、画面が寂しい。
    func testSettledIssuesAreCounted() throws {
        let db = try seeded()
        defer { try? db.close() }

        XCTAssertEqual(3, try StatsRepository(db: db).settledIssueCount())
    }

    /// §3.4 の目印が両方出る組み合わせを入れてある
    /// (影響度 3 × コスト 1 =「すぐ効く」/ 影響度 3 × コスト 3 =「シーズン単位」)。
    func testPriorityHintsAppearOnTheNextTier() throws {
        let db = try seeded()
        defer { try? db.close() }

        var hasQuickWin = false
        var hasSeasonLong = false
        for issue in try IssueRepository(db: db).fetch(tier: .next, statuses: [IssueStatus.active]) {
            let hint = PriorityHint.forIssue(impact: issue.impact, cost: issue.cost, tier: issue.tier)
            if hint == PriorityHint.quickWin {
                hasQuickWin = true
            }
            if hint == PriorityHint.seasonLong {
                hasSeasonLong = true
            }
        }
        XCTAssertTrue(hasQuickWin)
        XCTAssertTrue(hasSeasonLong)
    }

    // MARK: - 積み上げが見映えする

    /// 節目(§10.5)を越えた量を入れてある。100 時間 = 6000 分。
    func testBuildUpPassesTheHundredHourMilestone() throws {
        let db = try seeded()
        defer { try? db.close() }

        let minutes = try StatsRepository(db: db).lifetimeMinutes()

        XCTAssertTrue(minutes >= 6_000, "累計が少なすぎる: \(minutes) 分")
    }

    func testTrainingMenusAreChecked() throws {
        let db = try seeded()
        defer { try? db.close() }
        let training = TrainingRepository(db: db)

        XCTAssertEqual(4, try training.fetchMenus().count)
        // 今日は素振りだけ付いた状態(残りをチェックできる画面にする)
        XCTAssertEqual(1, try training.fetchLogs(on: today).count)
    }

    // MARK: - 仕掛けが誘ってくる

    /// 棚卸しの誘いが出る(「いつか」が 10 件以上 + 記録なし)。
    func testReviewIsDue() throws {
        let db = try seeded()
        defer { try? db.close() }

        let someday = try IssueRepository(db: db).fetch(tier: .someday, statuses: [IssueStatus.active])
        let lastReviewedAt = try AppMetaRepository(db: db).reviewLastDoneAt()

        XCTAssertNil(lastReviewedAt)
        XCTAssertTrue(ReviewSchedule.isDue(today: today,
                                           lastReviewedAt: lastReviewedAt,
                                           backlogCount: someday.count))
    }

    /// しばらく触れていない課題が実際に拾われる(撮りたい画面のひとつ)。
    func testStaleEvaluationFindsIssues() throws {
        let db = try seeded()
        defer { try? db.close() }

        try StaleEvaluator(db: db, now: { self.today }).evaluate()

        XCTAssertTrue(try StaleFlagRepository(db: db).fetchAll().count > 0)
    }

    /// 残り練習回数(§5.2)が数えられる。
    func testPracticePlanHasUpcomingDays() throws {
        let db = try seeded()
        defer { try? db.close() }

        let upcoming = try PracticePlanRepository(db: db).fetchUpcoming(asOf: today)

        XCTAssertTrue(upcoming.count > 0)
    }

    // MARK: - 何度押しても同じ

    /// 2 回入れても増えない(先に全部消してから入れている)。
    func testSeedingTwiceDoesNotDuplicate() throws {
        let db = try makeDatabase()
        defer { try? db.close() }

        try DemoData.seed(db: db, now: today)
        try DemoData.seed(db: db, now: today)

        XCTAssertEqual(12, try IssueRepository(db: db).fetch(tier: .someday, statuses: [IssueStatus.active]).count)
    }

    // MARK: - 消える

    /// **撮り終えたら消せること。** 残ると実データに混ざる。
    func testWipeRemovesEverything() throws {
        let db = try seeded()
        defer { try? db.close() }

        try DemoData.wipe(db: db)

        XCTAssertEqual(0, try IssueRepository(db: db).fetch().count)
        XCTAssertEqual(0, try CompetitionRepository(db: db).fetchAll().count)
        XCTAssertEqual(0, try TrainingRepository(db: db).fetchMenus().count)
        XCTAssertEqual(0, try StatsRepository(db: db).lifetimeMinutes())
        XCTAssertTrue(try VisionRepository(db: db).fetch().isEmpty)
        XCTAssertEqual(0, try PracticePlanRepository(db: db).fetchUpcoming(asOf: today).count)
    }

    /// 消したあとも設定は読める(`app_meta` は消さない)。
    func testWipeKeepsSettingsReadable() throws {
        let db = try seeded()
        defer { try? db.close() }

        try DemoData.wipe(db: db)

        XCTAssertEqual(21, try AppMetaRepository(db: db).staleThresholds().days)
    }
}
#endif
