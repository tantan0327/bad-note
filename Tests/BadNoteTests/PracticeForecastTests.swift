import XCTest
import Foundation
@testable import BadNote

/// 残り練習回数の推定(§5.2「残り日数 × 直近の平均練習頻度」)。
///
/// 純粋関数。DB も現在時刻も見ず、渡された値だけで決まる。
///
/// 基準は `asOf` = 2023-11-14T22:13:20Z。練習日は日単位でずらした値を使う。
final class PracticeForecastTests: XCTestCase {

    private let asOf = Date(timeIntervalSince1970: 1_700_000_000)

    /// asOf から days 日ずらした日付。
    private func day(_ days: Double) -> Date {
        return Date(timeIntervalSince1970: 1_700_000_000.0 + days * 86_400.0)
    }

    // MARK: - 平均間隔

    func testAverageIntervalIsNilForNoPractices() throws {
        let average = PracticeForecast.averageIntervalDays(practiceDates: [])

        XCTAssertNil(average, "履歴なしでは頻度を出せない")
    }

    /// 1 件では間隔が 1 つも作れない。
    func testAverageIntervalIsNilForSinglePractice() throws {
        let average = PracticeForecast.averageIntervalDays(practiceDates: [day(-3)])

        XCTAssertNil(average)
    }

    func testAverageIntervalOfTwoPractices() throws {
        let average = try XCTUnwrap(PracticeForecast.averageIntervalDays(practiceDates: [day(-3), day(0)]))

        XCTAssertEqual(3.0, average, accuracy: 0.0001)
    }

    /// 4 件で 9 日にまたがるなら間隔は 3 つ。9 / 3 = 3.0 日。
    func testAverageIntervalDividesSpanByGapCount() throws {
        let dates = [day(-9), day(-6), day(-3), day(0)]

        let average = try XCTUnwrap(PracticeForecast.averageIntervalDays(practiceDates: dates))

        XCTAssertEqual(3.0, average, accuracy: 0.0001)
    }

    /// 渡す順番に依存しない。
    func testAverageIntervalIgnoresOrderOfDates() throws {
        let dates = [day(0), day(-9), day(-3), day(-6)]

        let average = try XCTUnwrap(PracticeForecast.averageIntervalDays(practiceDates: dates))

        XCTAssertEqual(3.0, average, accuracy: 0.0001)
    }

    /// 全部同じ日なら期間が 0。ゼロ除算にせず「推定できない」を返す。
    func testAverageIntervalIsNilWhenAllPracticesOnSameDay() throws {
        let average = PracticeForecast.averageIntervalDays(practiceDates: [day(0), day(0), day(0)])

        XCTAssertNil(average)
    }

    // MARK: - 残り練習回数

    /// 3 日に 1 回のペースで、大会まで 30 日 → 10 回。
    func testRemainingCountMultipliesDaysByFrequency() throws {
        let dates = [day(-9), day(-6), day(-3), day(0)]

        let remaining = try XCTUnwrap(PracticeForecast.remainingPracticeCount(practiceDates: dates,
                                                                             eventDate: day(30),
                                                                             asOf: asOf))

        XCTAssertEqual(10, remaining)
    }

    func testRemainingCountUsesOnlyTwoPractices() throws {
        let dates = [day(-6), day(0)]

        let remaining = try XCTUnwrap(PracticeForecast.remainingPracticeCount(practiceDates: dates,
                                                                             eventDate: day(30),
                                                                             asOf: asOf))

        XCTAssertEqual(5, remaining)
    }

    /// 端数は切り捨て。30 / 4 = 7.5 → 7。多めに言わない。
    func testRemainingCountRoundsDown() throws {
        let dates = [day(-4), day(0)]

        let remaining = try XCTUnwrap(PracticeForecast.remainingPracticeCount(practiceDates: dates,
                                                                             eventDate: day(30),
                                                                             asOf: asOf))

        XCTAssertEqual(7, remaining)
    }

    /// 残り日数が平均間隔に届かないときは 0 回。
    func testRemainingCountIsZeroWhenLessThanOneIntervalLeft() throws {
        let dates = [day(-6), day(-3)]

        let remaining = try XCTUnwrap(PracticeForecast.remainingPracticeCount(practiceDates: dates,
                                                                             eventDate: day(2),
                                                                             asOf: asOf))

        XCTAssertEqual(0, remaining)
    }

    // MARK: - 履歴が足りないとき

    /// 履歴 0 件は「0 回」ではなく「推定できない」。
    /// 0 を返すと「もう間に合わない」に見えてしまう(§5 モチベーション設計)。
    func testRemainingCountIsNilWithoutHistory() throws {
        let remaining = PracticeForecast.remainingPracticeCount(practiceDates: [],
                                                                eventDate: day(30),
                                                                asOf: asOf)

        XCTAssertNil(remaining)
    }

    /// 1 件でも頻度は出せないので nil。
    func testRemainingCountIsNilWithSinglePractice() throws {
        let remaining = PracticeForecast.remainingPracticeCount(practiceDates: [day(-3)],
                                                                eventDate: day(30),
                                                                asOf: asOf)

        XCTAssertNil(remaining)
    }

    func testRemainingCountIsNilWhenAllPracticesOnSameDay() throws {
        let remaining = PracticeForecast.remainingPracticeCount(practiceDates: [day(-3), day(-3)],
                                                                eventDate: day(30),
                                                                asOf: asOf)

        XCTAssertNil(remaining)
    }

    // MARK: - 大会日の境界

    /// 大会が過ぎていたら 0。ここは「推定できない」ではなく確定した 0。
    func testRemainingCountIsZeroWhenEventIsInThePast() throws {
        let dates = [day(-6), day(0)]

        let remaining = try XCTUnwrap(PracticeForecast.remainingPracticeCount(practiceDates: dates,
                                                                             eventDate: day(-1),
                                                                             asOf: asOf))

        XCTAssertEqual(0, remaining)
    }

    /// 当日(残り 0 日)も 0 回。
    func testRemainingCountIsZeroWhenEventIsExactlyAsOf() throws {
        let dates = [day(-6), day(0)]

        let remaining = try XCTUnwrap(PracticeForecast.remainingPracticeCount(practiceDates: dates,
                                                                             eventDate: asOf,
                                                                             asOf: asOf))

        XCTAssertEqual(0, remaining)
    }

    /// 大会が過ぎているなら履歴が無くても 0。「推定できない」より確定情報が優先。
    func testRemainingCountIsZeroForPastEventEvenWithoutHistory() throws {
        let remaining = try XCTUnwrap(PracticeForecast.remainingPracticeCount(practiceDates: [],
                                                                             eventDate: day(-1),
                                                                             asOf: asOf))

        XCTAssertEqual(0, remaining)
    }

    /// 残り 1 日でも、その日に練習が入る見込みがあれば 1 回。
    func testRemainingCountCanBeOneOnTheLastDay() throws {
        let dates = [day(-1), day(0)]

        let remaining = try XCTUnwrap(PracticeForecast.remainingPracticeCount(practiceDates: dates,
                                                                             eventDate: day(1),
                                                                             asOf: asOf))

        XCTAssertEqual(1, remaining)
    }
}
