import XCTest
import Foundation
@testable import BadNote

/// 通知の計画(§8)。
///
/// **1 日 1 通まで。** 通知過多でオフにされると、忘れ防止の仕組みごと機能しなくなる。
///
/// 2023-11-19 は日曜、11-20 は月曜。テストは UTC 固定のカレンダーで行う。
final class NotificationPlanTests: XCTestCase {

    /// 2023-11-19T00:00:00Z(日曜)
    private let sunday = Date(timeIntervalSince1970: 1_700_352_000)
    /// 2023-11-20T00:00:00Z(月曜)
    private let monday = Date(timeIntervalSince1970: 1_700_438_400)
    /// 2023-11-21T00:00:00Z(火曜)
    private let tuesday = Date(timeIntervalSince1970: 1_700_524_800)

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// 月曜に練習リマインド、日曜が組み替えの曜日。
    private func settings() -> NotificationSettings {
        return NotificationSettings(isEnabled: true,
                                    practiceWeekdays: [1],
                                    practiceHour: 18,
                                    eveningHour: 20,
                                    reshuffleWeekday: 0)
    }

    // MARK: - 既定値

    func testDefaultsAreOffUntilTheUserOptsIn() throws {
        XCTAssertFalse(NotificationSettings.standard.isEnabled)
    }

    func testDefaultEveningHourIsEight() throws {
        XCTAssertEqual(20, NotificationSettings.standard.eveningHour)
    }

    // MARK: - どれを出すか

    /// 練習リマインドの曜日 → 今週の重点 3 つ。
    func testPracticeReminderOnConfiguredWeekday() throws {
        let planned = NotificationPlan.notification(on: monday,
                                                    settings: settings(),
                                                    isCompetitionDay: false,
                                                    calendar: utcCalendar())

        XCTAssertEqual(NotificationKind.practiceReminder, planned?.kind)
    }

    /// 組み替えの曜日 → しばらく触れていない課題。
    func testStaleReviewOnReshuffleWeekday() throws {
        let planned = NotificationPlan.notification(on: sunday,
                                                    settings: settings(),
                                                    isCompetitionDay: false,
                                                    calendar: utcCalendar())

        XCTAssertEqual(NotificationKind.staleReview, planned?.kind)
    }

    /// 大会当日 → 振り返りを促す。
    func testCompetitionReviewOnEventDay() throws {
        let planned = NotificationPlan.notification(on: tuesday,
                                                    settings: settings(),
                                                    isCompetitionDay: true,
                                                    calendar: utcCalendar())

        XCTAssertEqual(NotificationKind.competitionReview, planned?.kind)
    }

    /// 何も無い日は出さない。
    func testNothingOnOtherDays() throws {
        let planned = NotificationPlan.notification(on: tuesday,
                                                    settings: settings(),
                                                    isCompetitionDay: false,
                                                    calendar: utcCalendar())

        XCTAssertNil(planned)
    }

    func testNothingWhenDisabled() throws {
        var off = settings()
        off.isEnabled = false

        let planned = NotificationPlan.notification(on: monday,
                                                    settings: off,
                                                    isCompetitionDay: false,
                                                    calendar: utcCalendar())

        XCTAssertNil(planned)
    }

    // MARK: - 1 日 1 通(重なったときの優先)

    /// 大会当日が練習リマインドの曜日と重なったら、大会を優先する。
    func testCompetitionWinsOverPracticeReminder() throws {
        let planned = NotificationPlan.notification(on: monday,
                                                    settings: settings(),
                                                    isCompetitionDay: true,
                                                    calendar: utcCalendar())

        XCTAssertEqual(NotificationKind.competitionReview, planned?.kind)
    }

    /// 大会当日が組み替えの曜日と重なっても、大会を優先する。
    func testCompetitionWinsOverStaleReview() throws {
        let planned = NotificationPlan.notification(on: sunday,
                                                    settings: settings(),
                                                    isCompetitionDay: true,
                                                    calendar: utcCalendar())

        XCTAssertEqual(NotificationKind.competitionReview, planned?.kind)
    }

    /// 組み替えの曜日が練習リマインドの曜日と重なったら、組み替えを優先する。
    func testStaleReviewWinsOverPracticeReminder() throws {
        var both = settings()
        both.practiceWeekdays = [0]

        let planned = NotificationPlan.notification(on: sunday,
                                                    settings: both,
                                                    isCompetitionDay: false,
                                                    calendar: utcCalendar())

        XCTAssertEqual(NotificationKind.staleReview, planned?.kind)
    }

    // MARK: - 発火時刻

    func testPracticeReminderUsesConfiguredHour() throws {
        let planned = try XCTUnwrap(NotificationPlan.notification(on: monday,
                                                                  settings: settings(),
                                                                  isCompetitionDay: false,
                                                                  calendar: utcCalendar()))

        XCTAssertEqual(18, utcCalendar().component(Calendar.Component.hour, from: planned.date))
    }

    /// 大会の振り返りと stale は夜に出す(§8 大会当日の夜)。
    func testEveningNotificationsUseEveningHour() throws {
        let planned = try XCTUnwrap(NotificationPlan.notification(on: tuesday,
                                                                  settings: settings(),
                                                                  isCompetitionDay: true,
                                                                  calendar: utcCalendar()))

        XCTAssertEqual(20, utcCalendar().component(Calendar.Component.hour, from: planned.date))
    }

    // MARK: - 先の予定をまとめて作る

    /// 1 週間分を計画すると、月曜と日曜の 2 通だけになる。
    func testPlanCoversRequestedDaysWithOnePerDay() throws {
        let planned = NotificationPlan.plan(from: monday,
                                            days: 7,
                                            settings: settings(),
                                            competitionDates: [],
                                            calendar: utcCalendar())

        XCTAssertEqual(2, planned.count)
    }

    func testPlanIncludesCompetitionDay() throws {
        let planned = NotificationPlan.plan(from: monday,
                                            days: 3,
                                            settings: settings(),
                                            competitionDates: [tuesday],
                                            calendar: utcCalendar())

        XCTAssertEqual([NotificationKind.practiceReminder, NotificationKind.competitionReview],
                       planned.map { $0.kind })
    }

    func testPlanIsEmptyWhenDisabled() throws {
        var off = settings()
        off.isEnabled = false

        let planned = NotificationPlan.plan(from: monday,
                                            days: 30,
                                            settings: off,
                                            competitionDates: [tuesday],
                                            calendar: utcCalendar())

        XCTAssertEqual(0, planned.count)
    }
}
