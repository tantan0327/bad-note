import XCTest
import Foundation
@testable import BadNote

/// stale 判定の実行ゲート(§4.3)。
///
/// 判定は**週 1 回**だけ。毎日出すと無視されるようになる。
///
/// 2023-11-19 は日曜。テストは UTC 固定のカレンダーで行う。
final class StaleScheduleTests: XCTestCase {

    /// 2023-11-19T00:00:00Z(日曜)
    private let sunday = Date(timeIntervalSince1970: 1_700_352_000)
    /// 2023-11-20T00:00:00Z(月曜)
    private let monday = Date(timeIntervalSince1970: 1_700_438_400)

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func day(_ offset: Double, from base: Date) -> Date {
        return Date(timeIntervalSince1970: base.timeIntervalSince1970 + offset * 86_400.0)
    }

    /// 一度も評価していなければ実行する。
    func testRunsWhenNeverEvaluated() throws {
        let shouldRun = StaleSchedule.shouldEvaluate(today: monday,
                                                     lastEvaluatedAt: nil,
                                                     reshuffleWeekday: 0,
                                                     calendar: utcCalendar())

        XCTAssertTrue(shouldRun)
    }

    /// 組み替えの曜日なら実行する。
    func testRunsOnReshuffleWeekday() throws {
        let shouldRun = StaleSchedule.shouldEvaluate(today: sunday,
                                                     lastEvaluatedAt: day(-3, from: sunday),
                                                     reshuffleWeekday: 0,
                                                     calendar: utcCalendar())

        XCTAssertTrue(shouldRun)
    }

    /// 違う曜日では実行しない。
    func testDoesNotRunOnOtherWeekday() throws {
        let shouldRun = StaleSchedule.shouldEvaluate(today: monday,
                                                     lastEvaluatedAt: day(-1, from: monday),
                                                     reshuffleWeekday: 0,
                                                     calendar: utcCalendar())

        XCTAssertFalse(shouldRun)
    }

    /// 同じ日に 2 回目は実行しない(起動のたびに評価しない)。
    func testDoesNotRunTwiceOnSameDay() throws {
        let shouldRun = StaleSchedule.shouldEvaluate(today: day(0.5, from: sunday),
                                                     lastEvaluatedAt: day(0.1, from: sunday),
                                                     reshuffleWeekday: 0,
                                                     calendar: utcCalendar())

        XCTAssertFalse(shouldRun)
    }

    /// §4.3 取りこぼし救済: 7 日以上経っていれば曜日に関係なく実行する。
    func testRunsAfterSevenDaysRegardlessOfWeekday() throws {
        let shouldRun = StaleSchedule.shouldEvaluate(today: monday,
                                                     lastEvaluatedAt: day(-8, from: monday),
                                                     reshuffleWeekday: 0,
                                                     calendar: utcCalendar())

        XCTAssertTrue(shouldRun)
    }

    /// 境界: 6 日前ではまだ実行しない(組み替え曜日でもない)。
    func testDoesNotRunAfterSixDaysOnOtherWeekday() throws {
        let shouldRun = StaleSchedule.shouldEvaluate(today: monday,
                                                     lastEvaluatedAt: day(-6, from: monday),
                                                     reshuffleWeekday: 0,
                                                     calendar: utcCalendar())

        XCTAssertFalse(shouldRun)
    }

    /// 組み替え曜日は変えられる(§4.3 app_meta)。
    func testReshuffleWeekdayCanBeChanged() throws {
        let shouldRun = StaleSchedule.shouldEvaluate(today: monday,
                                                     lastEvaluatedAt: day(-1, from: monday),
                                                     reshuffleWeekday: 1,
                                                     calendar: utcCalendar())

        XCTAssertTrue(shouldRun, "月曜に設定すれば月曜に走る")
    }
}
