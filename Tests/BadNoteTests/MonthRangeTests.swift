import XCTest
import Foundation
@testable import BadNote

/// 月の範囲(§7.2 保存後に出す「今月の累計」の集計期間)。
///
/// 純粋関数。テストでは UTC 固定のカレンダーを渡して、実行環境のタイムゾーンに
/// 依存しないようにする。
final class MonthRangeTests: XCTestCase {

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    func testStartIsFirstDayOfMonth() throws {
        // 2023-11-14T22:13:20Z
        let range = MonthRange.containing(Date(timeIntervalSince1970: 1_700_000_000), calendar: utcCalendar())

        // 2023-11-01T00:00:00Z
        XCTAssertEqual(Date(timeIntervalSince1970: 1_698_796_800), range.start)
    }

    /// 終端は翌月の頭。この時刻は含まない(半開区間)。
    func testEndIsFirstDayOfNextMonth() throws {
        let range = MonthRange.containing(Date(timeIntervalSince1970: 1_700_000_000), calendar: utcCalendar())

        // 2023-12-01T00:00:00Z
        XCTAssertEqual(Date(timeIntervalSince1970: 1_701_388_800), range.end)
    }

    /// 12 月は年をまたぐ。
    func testDecemberRollsOverToNextYear() throws {
        // 2023-12-15T00:00:00Z
        let range = MonthRange.containing(Date(timeIntervalSince1970: 1_702_598_400), calendar: utcCalendar())

        // 2023-12-01 / 2024-01-01
        XCTAssertEqual(Date(timeIntervalSince1970: 1_701_388_800), range.start)
        XCTAssertEqual(Date(timeIntervalSince1970: 1_704_067_200), range.end)
    }

    /// 月初ちょうどは、その月の頭のまま。
    func testFirstDayOfMonthStaysAtStart() throws {
        let firstDay = Date(timeIntervalSince1970: 1_698_796_800)

        let range = MonthRange.containing(firstDay, calendar: utcCalendar())

        XCTAssertEqual(firstDay, range.start)
    }

    /// 月末も同じ月に入る。
    func testLastMomentOfMonthBelongsToSameMonth() throws {
        // 2023-11-30T23:59:59Z
        let range = MonthRange.containing(Date(timeIntervalSince1970: 1_701_388_799), calendar: utcCalendar())

        XCTAssertEqual(Date(timeIntervalSince1970: 1_698_796_800), range.start)
    }
}
