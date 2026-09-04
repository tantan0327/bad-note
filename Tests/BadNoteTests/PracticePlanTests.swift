import XCTest
import Foundation
@testable import BadNote

/// 残り練習回数の数え上げと、曜日からの日付生成(§5.2)。
///
/// **ここが境界規則の唯一の置き場。** 数え上げの SQL は作らない ——
/// 2 か所に分かれると片方だけ直る事故になる。
///
/// 暦は**日本時間に固定**する。UTC 固定だと「日本の朝 9 時が前日扱い」を見逃す。
final class PracticePlanTests: XCTestCase {

    private func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        if let zone = TimeZone(identifier: "Asia/Tokyo") {
            calendar.timeZone = zone
        }
        return calendar
    }

    /// 2026-09-07 は月曜。時刻を変えて渡せるようにしてある。
    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return makeCalendar().date(from: components) ?? Date()
    }

    private func today() -> Date {
        return date(2026, 9, 7)
    }

    private func count(_ planDays: [Date], to eventDate: Date, asOf: Date) -> Int? {
        return PracticePlan.remainingCount(planDays: planDays,
                                           eventDate: eventDate,
                                           asOf: asOf,
                                           calendar: makeCalendar())
    }

    // MARK: - 予定が無いときは回数を出さない

    /// **予定が 1 日も無ければ nil。** 0 ではない ——
    /// 0 は「もう間に合わない」に読めるが、実際は「まだ決めていない」。
    /// 画面はこれを見て、回数を出さずに設定へ誘導する。
    func testReturnsNilWhenThereAreNoPlannedDays() {
        XCTAssertNil(count([Date](), to: date(2026, 10, 5), asOf: today()))
    }

    /// **予定はあるが大会までに 1 日も無いときは 0**(nil ではない)。
    /// 「決めた上でこの大会までには無い」は事実であって、推定の欠如ではない。
    /// 足せばよいと分かる。
    func testReturnsZeroWhenPlanExistsButNoneBeforeTheEvent() {
        let planDays = [date(2026, 11, 4)]

        XCTAssertEqual(0, count(planDays, to: date(2026, 10, 5), asOf: today()))
    }

    // MARK: - 数え上げの境界

    /// **今日の予定は数える。** 「あと 42日」が今日を 0 日目として数えるので、
    /// 同じカードの 2 つの数字が別の暦を使わないようにする。
    func testCountsAPlannedDayToday() {
        let planDays = [today()]

        XCTAssertEqual(1, count(planDays, to: date(2026, 10, 5), asOf: today()))
    }

    /// 過ぎた予定は数えない。
    func testDoesNotCountPastDays() {
        let planDays = [date(2026, 9, 5), date(2026, 9, 6)]

        XCTAssertEqual(0, count(planDays, to: date(2026, 10, 5), asOf: today()))
    }

    /// 大会の前日は数える。
    func testCountsTheDayBeforeTheEvent() {
        let planDays = [date(2026, 10, 4)]

        XCTAssertEqual(1, count(planDays, to: date(2026, 10, 5), asOf: today()))
    }

    /// **大会当日の予定は数えない。** 準備に使えるのは前日まで。
    /// まとめて追加の既定期間(〜大会の前日)と数え方を揃える。
    func testDoesNotCountThePlannedDayOnTheEventItself() {
        let planDays = [date(2026, 10, 5)]

        XCTAssertEqual(0, count(planDays, to: date(2026, 10, 5), asOf: today()))
    }

    func testCountsEveryPlannedDayInBetween() {
        let planDays = [date(2026, 9, 8), date(2026, 9, 10), date(2026, 9, 12)]

        XCTAssertEqual(3, count(planDays, to: date(2026, 10, 5), asOf: today()))
    }

    /// 大会が過ぎていれば 0(予定が残っていても)。
    func testReturnsZeroWhenTheEventHasPassed() {
        let planDays = [date(2026, 9, 8)]

        XCTAssertEqual(0, count(planDays, to: date(2026, 9, 1), asOf: today()))
    }

    /// 今日が大会当日なら 0。
    func testReturnsZeroWhenTheEventIsToday() {
        let planDays = [date(2026, 9, 8)]

        XCTAssertEqual(0, count(planDays, to: today(), asOf: today()))
    }

    // MARK: - 渡し方に左右されない

    func testDoesNotDependOnTheOrderOfPlannedDays() {
        let planDays = [date(2026, 9, 12), date(2026, 9, 8), date(2026, 9, 10)]

        XCTAssertEqual(3, count(planDays, to: date(2026, 10, 5), asOf: today()))
    }

    /// **予定日や基準の時刻に左右されない。** 朝に開いても夜に開いても同じ数。
    func testDoesNotDependOnTheTimeOfDay() {
        let planDays = [date(2026, 9, 7, 23), date(2026, 9, 8, 1)]

        XCTAssertEqual(2, count(planDays, to: date(2026, 10, 5, 9), asOf: date(2026, 9, 7, 13)))
    }

    // MARK: - その日の予定日を引き当てる(§7.6 カレンダー)

    private func planDay(_ date: Date) -> PracticePlanDay {
        return PracticePlanDay(day: DayStamp().text(from: date), date: date)
    }

    private func planned(_ days: [PracticePlanDay], on day: Date) -> PracticePlanDay? {
        return PracticePlan.planned(days, on: day, calendar: makeCalendar())
    }

    /// カレンダーのセルが登録済みかを見るのと、**どの行を消すか**を 1 本の関数から出す。
    /// 別々にすると「印は付いているのに消えない」がありうる。
    func testFindsThePlanOnTheSameDay() {
        let days = [planDay(date(2026, 9, 8))]

        XCTAssertNotNil(planned(days, on: date(2026, 9, 8)))
    }

    /// 時刻が違っても同じ暦日なら見つかる。
    func testFindsThePlanRegardlessOfTime() {
        let days = [planDay(date(2026, 9, 8, 8))]

        XCTAssertNotNil(planned(days, on: date(2026, 9, 8, 23)))
    }

    func testReturnsNilForADayWithoutAPlan() {
        let days = [planDay(date(2026, 9, 8))]

        XCTAssertNil(planned(days, on: date(2026, 9, 9)))
    }

    func testReturnsNilWhenThereAreNoPlans() {
        XCTAssertNil(planned([PracticePlanDay](), on: date(2026, 9, 8)))
    }

    /// **月をまたいだ隣接日を取り違えない**(8/31 と 9/1)。
    func testDoesNotConfuseAdjacentDaysAcrossMonths() {
        let days = [planDay(date(2026, 8, 31))]

        XCTAssertNotNil(planned(days, on: date(2026, 8, 31)))
        XCTAssertNil(planned(days, on: date(2026, 9, 1)))
    }

    /// 返るのは**保存文字列を持った行そのもの**。そのまま削除に渡せる。
    func testReturnsTheStoredRowSoItCanBeDeleted() {
        let target = planDay(date(2026, 9, 8))
        let days = [planDay(date(2026, 9, 5)), target]

        var found: PracticePlanDay = planned(days, on: date(2026, 9, 8)) ?? planDay(date(2000, 1, 1))
        XCTAssertEqual(target.day, found.day)
    }

    // MARK: - 曜日から日付を作る

    private func dates(_ weekdays: [Int], _ from: Date, _ through: Date) -> [Date] {
        return PracticePlan.dates(weekdays: weekdays,
                                  from: from,
                                  through: through,
                                  calendar: makeCalendar())
    }

    /// **0 = 日曜**(`reshuffleWeekday` と同じ規約)。
    /// 2026-09-07 は月曜なので、月曜 = 1 を実日付で確かめる。
    func testWeekdayZeroIsSunday() {
        let generated = dates([1], today(), date(2026, 9, 13))

        XCTAssertEqual([date(2026, 9, 7)], generated)
    }

    func testGeneratesOneDayPerWeekForASingleWeekday() {
        let generated = dates([1], today(), date(2026, 9, 27))

        XCTAssertEqual(3, generated.count)
    }

    /// 複数の曜日は日付の昇順で混ざる。
    func testGeneratesMultipleWeekdaysInDateOrder() {
        let generated = dates([2, 4], today(), date(2026, 9, 13))

        XCTAssertEqual([date(2026, 9, 8), date(2026, 9, 10)], generated)
    }

    /// **両端を含む。** 利用者が選んだ終端が生成されないのは驚きになる
    /// (数え上げは半開区間だが、こちらは閉区間。非対称は意図的)。
    func testIncludesBothEnds() {
        let generated = dates([1], today(), date(2026, 9, 14))

        XCTAssertEqual([date(2026, 9, 7), date(2026, 9, 14)], generated)
    }

    func testGeneratesNothingWhenTheRangeIsReversed() {
        XCTAssertEqual(0, dates([1], date(2026, 9, 14), today()).count)
    }

    func testGeneratesNothingWithoutWeekdays() {
        XCTAssertEqual(0, dates([Int](), today(), date(2026, 9, 27)).count)
    }

    /// 同じ曜日を重ねて指定しても 1 日 1 件。
    func testDoesNotRepeatADayForADuplicatedWeekday() {
        let generated = dates([1, 1], today(), date(2026, 9, 13))

        XCTAssertEqual(1, generated.count)
    }

    /// 生成した日はすべてその日の 0 時。そのまま数え上げに渡せる。
    func testGeneratedDaysStartAtMidnight() {
        let generated = dates([1], date(2026, 9, 7, 15), date(2026, 9, 13))

        XCTAssertEqual([date(2026, 9, 7)], generated)
    }

    /// 期間の上限で打ち切る(暴走防止)。
    func testStopsAtTheSpanLimit() {
        let generated = dates([0, 1, 2, 3, 4, 5, 6], today(), date(2030, 9, 7))

        XCTAssertEqual(PracticePlan.maxSpanDays, generated.count)
    }

    /// 生成した日をそのまま数えると、生成した数と一致する
    /// (大会前日までを作れば、その全部が残り回数になる)。
    func testGeneratedDaysAreAllCounted() {
        let eventDate = date(2026, 10, 5)
        let generated = dates([2, 4], today(), date(2026, 10, 4))

        XCTAssertEqual(generated.count, count(generated, to: eventDate, asOf: today()))
    }
}
