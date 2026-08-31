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

    /// 日曜が組み替えの曜日。練習リマインドは**曜日ではなく練習予定日**で決まるので、
    /// 各テストが `isPracticeDay:` で渡す(§5.2 で曜日設定を廃止した)。
    private func settings() -> NotificationSettings {
        return NotificationSettings(isEnabled: true,
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

    /// 練習予定日 → 今週の重点 3 つ(§5.2 で曜日から予定日に変わった)。
    func testPracticeReminderOnAPlannedPracticeDay() throws {
        let planned = NotificationPlan.notification(on: monday,
                                                    settings: settings(),
                                                    isPracticeDay: true,
                                                    isCompetitionDay: false,
                                                    calendar: utcCalendar())

        XCTAssertEqual(NotificationKind.practiceReminder, planned?.kind)
    }

    /// 組み替えの曜日 → しばらく触れていない課題。
    func testStaleReviewOnReshuffleWeekday() throws {
        let planned = NotificationPlan.notification(on: sunday,
                                                    settings: settings(),
                                                    isPracticeDay: false,
                                                    isCompetitionDay: false,
                                                    calendar: utcCalendar())

        XCTAssertEqual(NotificationKind.staleReview, planned?.kind)
    }

    /// 大会当日 → 振り返りを促す。
    func testCompetitionReviewOnEventDay() throws {
        let planned = NotificationPlan.notification(on: tuesday,
                                                    settings: settings(),
                                                    isPracticeDay: false,
                                                    isCompetitionDay: true,
                                                    calendar: utcCalendar())

        XCTAssertEqual(NotificationKind.competitionReview, planned?.kind)
    }

    /// 何も無い日は出さない。
    func testNothingOnOtherDays() throws {
        let planned = NotificationPlan.notification(on: tuesday,
                                                    settings: settings(),
                                                    isPracticeDay: false,
                                                    isCompetitionDay: false,
                                                    calendar: utcCalendar())

        XCTAssertNil(planned)
    }

    func testNothingWhenDisabled() throws {
        var off = settings()
        off.isEnabled = false

        let planned = NotificationPlan.notification(on: monday,
                                                    settings: off,
                                                    isPracticeDay: true,
                                                    isCompetitionDay: false,
                                                    calendar: utcCalendar())

        XCTAssertNil(planned)
    }

    // MARK: - 1 日 1 通(重なったときの優先)

    /// 大会当日が練習予定日と重なったら、大会を優先する。
    func testCompetitionWinsOverPracticeReminder() throws {
        let planned = NotificationPlan.notification(on: monday,
                                                    settings: settings(),
                                                    isPracticeDay: true,
                                                    isCompetitionDay: true,
                                                    calendar: utcCalendar())

        XCTAssertEqual(NotificationKind.competitionReview, planned?.kind)
    }

    /// 大会当日が組み替えの曜日と重なっても、大会を優先する。
    func testCompetitionWinsOverStaleReview() throws {
        let planned = NotificationPlan.notification(on: sunday,
                                                    settings: settings(),
                                                    isPracticeDay: false,
                                                    isCompetitionDay: true,
                                                    calendar: utcCalendar())

        XCTAssertEqual(NotificationKind.competitionReview, planned?.kind)
    }

    /// 組み替えの曜日が練習予定日と重なったら、組み替えを優先する。
    func testStaleReviewWinsOverPracticeReminder() throws {
        let planned = NotificationPlan.notification(on: sunday,
                                                    settings: settings(),
                                                    isPracticeDay: true,
                                                    isCompetitionDay: false,
                                                    calendar: utcCalendar())

        XCTAssertEqual(NotificationKind.staleReview, planned?.kind)
    }

    // MARK: - 発火時刻

    func testPracticeReminderUsesConfiguredHour() throws {
        let planned = try XCTUnwrap(NotificationPlan.notification(on: monday,
                                                                  settings: settings(),
                                                                  isPracticeDay: true,
                                                                  isCompetitionDay: false,
                                                                  calendar: utcCalendar()))

        XCTAssertEqual(18, utcCalendar().component(Calendar.Component.hour, from: planned.date))
    }

    /// 大会の振り返りと stale は夜に出す(§8 大会当日の夜)。
    func testEveningNotificationsUseEveningHour() throws {
        let planned = try XCTUnwrap(NotificationPlan.notification(on: tuesday,
                                                                  settings: settings(),
                                                                  isPracticeDay: false,
                                                                  isCompetitionDay: true,
                                                                  calendar: utcCalendar()))

        XCTAssertEqual(20, utcCalendar().component(Calendar.Component.hour, from: planned.date))
    }

    /// 時刻は分まで指定できる(2.5。DatePicker で「時:分」を選ぶ)。
    func testPracticeReminderUsesConfiguredMinute() throws {
        var custom = settings()
        custom.practiceMinute = 30
        let planned = try XCTUnwrap(NotificationPlan.notification(on: monday,
                                                                  settings: custom,
                                                                  isPracticeDay: true,
                                                                  isCompetitionDay: false,
                                                                  calendar: utcCalendar()))

        XCTAssertEqual(18, utcCalendar().component(Calendar.Component.hour, from: planned.date))
        XCTAssertEqual(30, utcCalendar().component(Calendar.Component.minute, from: planned.date))
    }

    func testEveningNotificationsUseEveningMinute() throws {
        var custom = settings()
        custom.eveningMinute = 45
        let planned = try XCTUnwrap(NotificationPlan.notification(on: tuesday,
                                                                  settings: custom,
                                                                  isPracticeDay: false,
                                                                  isCompetitionDay: true,
                                                                  calendar: utcCalendar()))

        XCTAssertEqual(45, utcCalendar().component(Calendar.Component.minute, from: planned.date))
    }

    /// 分を指定しなければ 0 分(従来の設定と互換)。
    func testMinutesDefaultToZero() throws {
        let planned = try XCTUnwrap(NotificationPlan.notification(on: monday,
                                                                  settings: settings(),
                                                                  isPracticeDay: true,
                                                                  isCompetitionDay: false,
                                                                  calendar: utcCalendar()))

        XCTAssertEqual(0, utcCalendar().component(Calendar.Component.minute, from: planned.date))
    }

    // MARK: - 先の予定をまとめて作る

    /// 1 週間分を計画すると、練習予定日(月曜)と組み替えの曜日(日曜)の 2 通だけになる。
    func testPlanCoversRequestedDaysWithOnePerDay() throws {
        let planned = NotificationPlan.plan(from: monday,
                                            days: 7,
                                            settings: settings(),
                                            practicePlanDates: [monday],
                                            competitionDates: [],
                                            calendar: utcCalendar())

        XCTAssertEqual(2, planned.count)
    }

    func testPlanIncludesCompetitionDay() throws {
        let planned = NotificationPlan.plan(from: monday,
                                            days: 3,
                                            settings: settings(),
                                            practicePlanDates: [monday],
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
                                            practicePlanDates: [monday],
                                            competitionDates: [tuesday],
                                            calendar: utcCalendar())

        XCTAssertEqual(0, planned.count)
    }
}
