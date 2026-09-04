import XCTest
import Foundation
import SkipSQL
@testable import BadNote

/// 練習予定日の永続化(§5.2)。対象は `practice_plan`。
///
/// - DB はテストごとに新規のインメモリ
/// - 保存の単位は**ローカルの暦日**。同じ日は 1 行しか持てない(主キー)
final class PracticePlanRepositoryTests: XCTestCase {

    /// 2026-09-07(月)13:00 JST。**午後**にしてあるのは、
    /// 「今日の予定が時刻のせいで落ちる」という取りこぼしを踏むため。
    private let t0 = Date(timeIntervalSince1970: 1_788_753_600)

    private var clock = Date(timeIntervalSince1970: 1_788_753_600)

    private func makeDatabase() throws -> SQLContext {
        let db = SQLContext(configuration: .platform)
        try AppDatabase.prepare(db)
        return db
    }

    private func makeRepository(_ db: SQLContext) -> PracticePlanRepository {
        clock = t0
        return PracticePlanRepository(db: db, now: { self.clock })
    }

    /// `t0` から日数をずらした日の 12 時。
    private func day(_ days: Int) -> Date {
        return t0.addingTimeInterval(Double(days) * 86_400 - 3_600)
    }

    /// 2026 年の指定した月日の 12 時。月境界のテスト用。
    private func monthDay(_ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = month
        components.day = day
        components.hour = 12
        return Calendar.current.date(from: components) ?? t0
    }

    // MARK: - 追加

    func testAddStoresTheDay() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        try repo.add(day(1))

        XCTAssertEqual(1, try repo.fetchAll().count)
    }

    /// 同じ日を 2 回追加しても 1 行(主キーが `plan_date`)。
    /// まとめて追加を何度押しても増えないことがこれで保証される。
    func testAddingTheSameDayTwiceKeepsOneRow() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        try repo.add(day(1))
        try repo.add(day(1))

        XCTAssertEqual(1, try repo.fetchAll().count)
    }

    /// **同じ日の朝と夜は同じ 1 行。** 保存の単位が暦日であることの確認。
    func testDifferentTimesOnTheSameDayAreOneRow() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        try repo.add(t0.addingTimeInterval(-46_800))
        try repo.add(t0.addingTimeInterval(36_000))

        XCTAssertEqual(1, try repo.fetchAll().count)
    }

    /// 二重追加で `created_at` を書き換えない(`INSERT OR IGNORE`。`OR REPLACE` ではない)。
    /// 先に決めた日を、後のまとめて追加が上書きしないため。
    func testAddingAgainDoesNotChangeCreatedAt() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)
        try repo.add(day(1))
        let firstRows = try db.selectAll(sql: "SELECT created_at FROM practice_plan")
        var firstCreatedAt: String = try XCTUnwrap(firstRows.first?.first?.textValue)

        clock = t0.addingTimeInterval(86_400)
        try repo.add(day(1))

        let rows = try db.selectAll(sql: "SELECT created_at FROM practice_plan")
        var createdAt: String = try XCTUnwrap(rows.first?.first?.textValue)
        XCTAssertEqual(firstCreatedAt, createdAt)
    }

    func testAddAllStoresEveryDay() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        try repo.addAll([day(1), day(3), day(5)])

        XCTAssertEqual(3, try repo.fetchAll().count)
    }

    /// まとめて追加に既存の日が混ざっていても増えない。
    func testAddAllSkipsDaysThatAlreadyExist() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)
        try repo.add(day(3))

        try repo.addAll([day(1), day(3), day(5)])

        XCTAssertEqual(3, try repo.fetchAll().count)
    }

    func testAddAllWithNoDaysStoresNothing() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        try repo.addAll([Date]())

        XCTAssertEqual(0, try repo.fetchAll().count)
    }

    // MARK: - 削除

    func testRemoveDeletesTheDay() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)
        try repo.addAll([day(1), day(3)])
        var target: PracticePlanDay = try XCTUnwrap(try repo.fetchAll().first)

        try repo.remove(target)

        let remaining = try repo.fetchAll()
        XCTAssertEqual(1, remaining.count)
        XCTAssertFalse(remaining.contains(target))
    }

    /// 無い日を消しても落ちない(一覧を開いたまま別の場所で消された場合)。
    func testRemovingAMissingDayDoesNothing() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)
        try repo.add(day(1))

        try repo.remove(PracticePlanDay(day: "2099-01-01", date: day(9)))

        XCTAssertEqual(1, try repo.fetchAll().count)
    }

    // MARK: - 取り出し

    /// 古い順。一覧は上から日付順に並ぶ。
    func testFetchAllIsOrderedOldestFirst() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        try repo.addAll([day(5), day(1), day(3)])

        let days = try repo.fetchAll()
        XCTAssertEqual(3, days.count)
        XCTAssertTrue(days[0].day < days[1].day)
        XCTAssertTrue(days[1].day < days[2].day)
    }

    func testFetchUpcomingExcludesPastDays() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)
        try repo.addAll([day(-1), day(1)])

        let days = try repo.fetchUpcoming(asOf: t0)

        XCTAssertEqual(1, days.count)
    }

    /// **13 時に開いても今日の予定は残る。**
    ///
    /// 絞り込みが暦日の文字列比較なので、時刻を持ち込みようがない。
    /// 大会の取り出しで一度踏んだ罠(`NotificationServiceTests` の
    /// `testIncludesTonightsReviewForACompetitionEarlierToday`)を、
    /// ここでは構造的に避けている —— それを固定する。
    func testFetchUpcomingKeepsTodayEvenWhenCalledInTheAfternoon() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)
        // 今日の朝 8 時の予定を、13 時(= t0)に問い合わせる
        try repo.add(t0.addingTimeInterval(-18_000))

        let days = try repo.fetchUpcoming(asOf: t0)

        XCTAssertEqual(1, days.count)
    }

    /// 取り出した `date` はその日の 0 時。数え上げの区間の端に使うので時刻を持たない。
    func testFetchedDateStartsAtMidnight() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)
        try repo.add(day(1))

        var stored: PracticePlanDay = try XCTUnwrap(try repo.fetchAll().first)

        let components = Calendar.current.dateComponents([Calendar.Component.hour,
                                                          Calendar.Component.minute],
                                                         from: stored.date)
        XCTAssertEqual(0, components.hour)
        XCTAssertEqual(0, components.minute)
    }

    /// `day` と `date` が食い違わない(同じ 1 行から復号している)。
    func testStoredDayAndDateAgree() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)
        try repo.add(day(1))

        var stored: PracticePlanDay = try XCTUnwrap(try repo.fetchAll().first)

        XCTAssertEqual(stored.day, DayStamp().text(from: stored.date))
    }

    // MARK: - 期間で取り出す(§7.6 カレンダー)

    /// カレンダーは**見えている 42 日分だけ**を読む。
    /// `fetchAll` だと毎タップで全期間を読み、判定が View 層に落ちてテストできなくなる。
    func testFetchRangeReturnsOnlyDaysInside() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)
        try repo.addAll([day(-1), day(1), day(3), day(5)])

        let days = try repo.fetchRange(from: day(1), through: day(3))

        XCTAssertEqual(2, days.count)
    }

    /// **両端を含む**(`PracticePlan.dates(from:through:)` と揃える)。
    func testFetchRangeIncludesBothEnds() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)
        try repo.addAll([day(1), day(5)])

        let days = try repo.fetchRange(from: day(1), through: day(5))

        XCTAssertEqual(2, days.count)
    }

    func testFetchRangeIsOrderedOldestFirst() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)
        try repo.addAll([day(5), day(1), day(3)])

        let days = try repo.fetchRange(from: day(0), through: day(9))

        XCTAssertEqual(3, days.count)
        XCTAssertTrue(days[0].day < days[1].day)
        XCTAssertTrue(days[1].day < days[2].day)
    }

    /// 月の境界。9/1〜10/1 に 8/31 は入らず、9/30 と 10/1 は入る。
    func testFetchRangeHandlesMonthBoundaries() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)
        try repo.addAll([monthDay(8, 31), monthDay(9, 30), monthDay(10, 1)])

        let days = try repo.fetchRange(from: monthDay(9, 1), through: monthDay(10, 1))

        XCTAssertEqual(2, days.count)
    }

    /// **時刻に左右されない**(暦日の文字列で比較しているため)。
    func testFetchRangeIgnoresTheTimeOfDay() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)
        try repo.add(day(1))

        // 朝 8 時から夜 23 時までを指定しても、同じ暦日の 1 件が返る
        let days = try repo.fetchRange(from: day(1).addingTimeInterval(-18_000),
                                       through: day(1).addingTimeInterval(39_600))

        XCTAssertEqual(1, days.count)
    }

    func testFetchRangeReturnsNothingWhenEmpty() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let days = try repo.fetchRange(from: day(1), through: day(5))

        XCTAssertEqual(0, days.count)
    }

    /// 逆転した期間は空(呼び出し側で弾く前提だが、落ちないこと)。
    func testFetchRangeReturnsNothingWhenReversed() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)
        try repo.addAll([day(1), day(3)])

        let days = try repo.fetchRange(from: day(5), through: day(1))

        XCTAssertEqual(0, days.count)
    }

    // MARK: - 保存形式

    /// **保存されている文字列そのもの**を検査する(開発メモ
    /// 「保存形式は保存された文字列そのものを検査する」)。
    ///
    /// 期待値はリテラルで書き、日付は**ゼロ埋めが要る 1 月 4 日**を選ぶ ——
    /// 2 桁同士だと `yyyy-M-d` に変わっても同じ 10 文字で気づけない。
    func testPlanDateIsStoredAsLocalDayText() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 4
        components.hour = 12
        let january4: Date = try XCTUnwrap(Calendar.current.date(from: components))

        try repo.add(january4)

        let rows = try db.selectAll(sql: "SELECT plan_date FROM practice_plan")
        var storedText: String = try XCTUnwrap(rows.first?.first?.textValue)
        XCTAssertEqual("2026-01-04", storedText)
    }
}
