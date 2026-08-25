import XCTest
import Foundation
@testable import BadNote

/// 日付の表示(2026-08-25)。
///
/// アプリの UI は日本語のみなので、**端末のロケールに関係なく日本語で出す**。
/// それまで家トレだけが `ja_JP` 固定で、他の 5 画面は端末任せ(英語が出ていた)。
final class DateTextTests: XCTestCase {

    /// ローカルの暦日で組み立てる(タイムゾーン差で 1 日ずれないように)。
    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return Calendar.current.date(from: components) ?? Date()
    }

    // MARK: - 同じ年は年を出さない

    func testDayWithinSameYear() {
        let text = DateText.day(date(2026, 8, 24), asOf: date(2026, 8, 25))
        XCTAssertEqual(text, "8月24日")
    }

    func testDayWithWeekdayWithinSameYear() {
        // 2026-08-24 は月曜
        let text = DateText.dayWithWeekday(date(2026, 8, 24), asOf: date(2026, 8, 25))
        XCTAssertEqual(text, "8月24日(月)")
    }

    // MARK: - 年が違えば年を出す

    /// 一覧で「8月24日」とだけ出ると、去年の記録が今年のものに見える。
    func testDayShowsYearWhenDifferent() {
        let text = DateText.day(date(2025, 8, 24), asOf: date(2026, 8, 25))
        XCTAssertEqual(text, "2025年8月24日")
    }

    /// 目標大会は年をまたぐことが多い(半年先など)。
    func testDayWithWeekdayShowsYearWhenDifferent() {
        // 2027-02-20 は土曜
        let text = DateText.dayWithWeekday(date(2027, 2, 20), asOf: date(2026, 8, 25))
        XCTAssertEqual(text, "2027年2月20日(土)")
    }

    // MARK: - 端末のロケールに影響されない

    /// **英語ロケールの端末でも日本語で出す。** これが直したかったこと。
    func testUsesJapaneseRegardlessOfDeviceLocale() {
        let text = DateText.dayWithWeekday(date(2026, 8, 24), asOf: date(2026, 8, 25))
        XCTAssertFalse(text.contains("Aug"))
        XCTAssertTrue(text.contains("月"))
    }

    /// 月と日はゼロ詰めしない(「08月04日」にしない)。
    func testDoesNotPadMonthAndDay() {
        let text = DateText.day(date(2026, 1, 4), asOf: date(2026, 8, 25))
        XCTAssertEqual(text, "1月4日")
    }
}
