import XCTest
import Foundation
@testable import BadNote

/// 月カレンダーの升目(§7.6)。
///
/// **常にちょうど 42 個(6 週 × 7 日)、先頭は必ず日曜。**
/// 42 固定なのは View を定数レンジ(`ForEach(0..<6)` / `ForEach(0..<7)`)で回せて、
/// 月を送ってもカレンダーの高さが跳ねないため。
///
/// 暦は**日本時間に固定**する。端末の暦に任せると機械のタイムゾーンで結果が変わる。
final class MonthGridTests: XCTestCase {

    private func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        if let zone = TimeZone(identifier: "Asia/Tokyo") {
            calendar.timeZone = zone
        }
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return makeCalendar().date(from: components) ?? Date()
    }

    private func cells(_ year: Int, _ month: Int, _ day: Int = 1, _ hour: Int = 0) -> [MonthGridDay] {
        return MonthGrid.cells(of: date(year, month, day, hour), calendar: makeCalendar())
    }

    /// その日を含むか。`contains(where:)` はこのリポジトリで実績が無いので明示的に回す。
    private func contains(_ grid: [MonthGridDay], _ target: Date) -> Bool {
        for cell in grid {
            if cell.date == target {
                return true
            }
        }
        return false
    }

    /// その月の日として `dayNumber` を含むか。
    private func containsDayNumber(_ grid: [MonthGridDay], _ number: Int) -> Bool {
        for cell in grid {
            if cell.isInMonth && cell.dayNumber == number {
                return true
            }
        }
        return false
    }

    /// その月に属するセルだけ取り出す。
    private func inMonth(_ grid: [MonthGridDay]) -> [MonthGridDay] {
        var result: [MonthGridDay] = []
        for cell in grid {
            if cell.isInMonth {
                result.append(cell)
            }
        }
        return result
    }

    // MARK: - 個数と形

    func testAlwaysReturnsFortyTwoCells() {
        XCTAssertEqual(42, cells(2026, 9).count)
        XCTAssertEqual(42, cells(2026, 2).count)
        XCTAssertEqual(42, cells(2026, 8).count)
        XCTAssertEqual(42, cells(2028, 2).count)
    }

    func testCellCountMatchesTheDeclaredConstant() {
        XCTAssertEqual(MonthGrid.cellCount, cells(2026, 9).count)
        XCTAssertEqual(MonthGrid.weekCount * MonthGrid.dayCount, MonthGrid.cellCount)
    }

    /// **先頭は必ず日曜。** 曜日の見出し(`WeekdayName.of`、0 = 日曜)と揃える。
    func testFirstCellIsAlwaysSunday() {
        let calendar = makeCalendar()
        for month in 1...12 {
            let grid = cells(2026, month)
            var first: MonthGridDay = grid[0]
            XCTAssertEqual(1, calendar.component(Calendar.Component.weekday, from: first.date),
                           "\(month) 月の先頭が日曜でない")
        }
    }

    /// **端末の暦の設定に引きずられない。** 月曜始まりの暦を渡しても先頭は日曜。
    /// en-GB の端末で 1 日ずれるのを防ぐ。
    func testFirstCellIsSundayEvenWithAMondayFirstCalendar() {
        var calendar = makeCalendar()
        calendar.firstWeekday = 2

        let grid = MonthGrid.cells(of: date(2026, 9, 1), calendar: calendar)

        var first: MonthGridDay = grid[0]
        XCTAssertEqual(1, calendar.component(Calendar.Component.weekday, from: first.date))
    }

    /// 42 個が 1 日ずつ連続している(穴が無い)。
    func testCellsAreConsecutiveDays() {
        let calendar = makeCalendar()
        let grid = cells(2026, 9)

        for index in 1..<grid.count {
            let expected = calendar.date(byAdding: Calendar.Component.day, value: 1, to: grid[index - 1].date)
            XCTAssertEqual(expected, grid[index].date, "\(index) 番目が連続していない")
        }
    }

    /// すべてのセルがその日の 0 時。そのまま数え上げに渡せる。
    func testEveryCellStartsAtMidnight() {
        let calendar = makeCalendar()

        for cell in cells(2026, 9) {
            let components = calendar.dateComponents([Calendar.Component.hour,
                                                      Calendar.Component.minute],
                                                     from: cell.date)
            XCTAssertEqual(0, components.hour)
            XCTAssertEqual(0, components.minute)
        }
    }

    /// 月中の日でも時刻つきでも同じ 42 個になる(月頭に丸めている)。
    func testAnyDayInTheMonthGivesTheSameGrid() {
        let first = cells(2026, 9, 1, 0)
        let middle = cells(2026, 9, 15, 13)
        let last = cells(2026, 9, 30, 23)

        XCTAssertEqual(first, middle)
        XCTAssertEqual(first, last)
    }

    // MARK: - 月初の位置

    /// 2026-09-01 は火曜。日曜始まりなので 2 つずれる。
    func testMonthStartsAtItsWeekdayOffset() {
        let grid = cells(2026, 9)

        XCTAssertEqual(date(2026, 9, 1), grid[2].date)
        XCTAssertTrue(grid[2].isInMonth)
        XCTAssertFalse(grid[1].isInMonth)
    }

    /// 2026-02-01 は**日曜**。オフセット 0 の端。
    func testMonthStartingOnSundayHasNoLeadingCells() {
        let grid = cells(2026, 2)

        XCTAssertEqual(date(2026, 2, 1), grid[0].date)
        XCTAssertTrue(grid[0].isInMonth)
    }

    /// 2026-08-01 は**土曜**でその月は 31 日。オフセット 6 + 31 = 37 で 42 に収まる。
    /// **42 セルで必ず足りる**ことの実証。
    func testMonthStartingOnSaturdayStillFits() {
        let grid = cells(2026, 8)

        XCTAssertEqual(date(2026, 8, 1), grid[6].date)
        XCTAssertEqual(date(2026, 8, 31), grid[36].date)
        XCTAssertTrue(grid[36].isInMonth)
    }

    // MARK: - 月外のセル

    /// **前後の月の日で埋める**(空白にしない)。
    /// 2026-02 は日曜始まりの 28 日なので、空白だと下 2 行が丸ごと空く。
    func testCellsOutsideTheMonthAreFilledWithNeighbouringDays() {
        let grid = cells(2026, 2)

        var last: MonthGridDay = grid[41]
        XCTAssertFalse(last.isInMonth)
        XCTAssertEqual(date(2026, 3, 14), last.date)
    }

    /// 先頭側の月外セルは前月の末尾。
    func testLeadingCellsComeFromThePreviousMonth() {
        let grid = cells(2026, 9)

        XCTAssertEqual(date(2026, 8, 30), grid[0].date)
        XCTAssertEqual(date(2026, 8, 31), grid[1].date)
        XCTAssertFalse(grid[0].isInMonth)
    }

    func testInMonthCountMatchesTheLengthOfTheMonth() {
        XCTAssertEqual(30, inMonth(cells(2026, 9)).count)
        XCTAssertEqual(31, inMonth(cells(2026, 8)).count)
        XCTAssertEqual(28, inMonth(cells(2026, 2)).count)
    }

    /// その月のセルは**連続した 1 区間**(先頭と末尾に分かれない)。
    func testInMonthCellsFormOneRun() {
        let grid = cells(2026, 9)
        var started = false
        var ended = false

        for cell in grid {
            if cell.isInMonth {
                XCTAssertFalse(ended, "その月のセルが 2 区間に分かれている")
                started = true
            } else if started {
                ended = true
            }
        }
        XCTAssertTrue(started)
    }

    // MARK: - うるう年

    func testLeapYearHasTwentyNineDays() {
        let grid = cells(2028, 2)

        XCTAssertEqual(29, inMonth(grid).count)
        XCTAssertTrue(containsDayNumber(grid, 29))
    }

    func testCommonYearHasTwentyEightDays() {
        let grid = cells(2026, 2)

        XCTAssertEqual(28, inMonth(grid).count)
        XCTAssertFalse(containsDayNumber(grid, 29))
    }

    // MARK: - 年またぎ

    func testDecemberGridReachesIntoJanuary() {
        let grid = cells(2026, 12)

        XCTAssertTrue(contains(grid, date(2027, 1, 1)))
    }

    func testJanuaryGridReachesBackIntoDecember() {
        let grid = cells(2027, 1)

        XCTAssertTrue(contains(grid, date(2026, 12, 31)))
    }

    // MARK: - 画面に出す数字

    func testDayNumberMatchesTheDate() {
        let calendar = makeCalendar()

        for cell in cells(2026, 9) {
            XCTAssertEqual(calendar.component(Calendar.Component.day, from: cell.date), cell.dayNumber)
        }
    }

    // MARK: - 月送り

    private func shifted(_ year: Int, _ month: Int, _ day: Int, by months: Int) -> Date {
        return MonthGrid.shifted(date(year, month, day), by: months, calendar: makeCalendar())
    }

    func testShiftForwardMovesToTheNextMonth() {
        XCTAssertEqual(date(2026, 10, 1), shifted(2026, 9, 1, by: 1))
    }

    /// 12 月から進むと**翌年**の 1 月。
    func testShiftForwardCrossesTheYear() {
        XCTAssertEqual(date(2027, 1, 1), shifted(2026, 12, 1, by: 1))
    }

    /// 1 月から戻ると**前年**の 12 月。
    func testShiftBackCrossesTheYear() {
        XCTAssertEqual(date(2025, 12, 1), shifted(2026, 1, 1, by: -1))
    }

    /// **31 日の月から 1 か月進めても 3 月に飛ばない。**
    /// 月初に丸めてから足しているので起きないが、古典的な落とし穴なので固定する。
    func testShiftFromTheEndOfAMonthDoesNotSkip() {
        XCTAssertEqual(date(2026, 2, 1), shifted(2026, 1, 31, by: 1))
    }

    /// 月中を渡してもその月の 1 日に丸まる。
    func testShiftByZeroRoundsToTheFirstOfTheMonth() {
        XCTAssertEqual(date(2026, 9, 1), shifted(2026, 9, 15, by: 0))
    }

    func testShiftByTwelveMonthsKeepsTheMonth() {
        XCTAssertEqual(date(2027, 9, 1), shifted(2026, 9, 1, by: 12))
    }

    /// 月送りで巻き戻らない(次の月の先頭は今の月の末尾より後)。
    func testShiftingForwardNeverGoesBackwards() {
        let current = cells(2026, 9)
        let next = MonthGrid.cells(of: shifted(2026, 9, 1, by: 1), calendar: makeCalendar())

        var currentLast: MonthGridDay = current[41]
        var nextLast: MonthGridDay = next[41]
        XCTAssertTrue(currentLast.date < nextLast.date)
    }
}
