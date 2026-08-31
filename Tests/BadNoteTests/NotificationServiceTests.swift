import XCTest
import Foundation
import SkipSQL
@testable import BadNote

/// 通知の予定を DB から組み立てる部分(§8)。
///
/// **`NotificationPlanTests` では守れないところだけを見る。** あちらは純粋関数
/// (どの曜日に何を出すか、重なったときの優先)で、こちらは**その手前の配線** ——
/// 設定と大会を DB から正しく拾えているか、過ぎた時刻を落とせているか。
/// `plannedNotifications` はホーム(`HomeModel`)と通知設定画面の両方から呼ばれる。
///
/// - DB はテストごとに新規のインメモリ
/// - **暦は日本時間に固定**する。UTC 前提の書き方が紛れ込んでも気づけるように
///   (端末の暦に任せると、機械のタイムゾーン次第で通ったり落ちたりする)
final class NotificationServiceTests: XCTestCase {

    /// 2026-09-07(月)13:00 JST。「今」の基準。
    /// 午後にしてあるのは、**朝の予定が既に過ぎている**状況を作るため。
    private let now = Date(timeIntervalSince1970: 1_788_753_600)

    private func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        if let zone = TimeZone(identifier: "Asia/Tokyo") {
            calendar.timeZone = zone
        }
        return calendar
    }

    private func makeDatabase() throws -> SQLContext {
        let db = SQLContext(configuration: .platform)
        try AppDatabase.prepare(db)
        return db
    }

    private func makeService(_ db: SQLContext) -> NotificationService {
        return NotificationService(db: db, calendar: makeCalendar())
    }

    /// `now` から `days` 日ずらした日の `hour:minute`。
    private func day(_ days: Int, at hour: Int, _ minute: Int = 0) -> Date {
        let calendar = makeCalendar()
        let base = calendar.date(byAdding: Calendar.Component.day, value: days, to: now) ?? now
        var components = calendar.dateComponents([Calendar.Component.year,
                                                  Calendar.Component.month,
                                                  Calendar.Component.day],
                                                 from: base)
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components) ?? base
    }

    /// `now` の曜日(0 = 日曜)。曜日はハードコードせず暦から取る ——
    /// 「今日の曜日に鳴る設定」と読めるようにして、暦の数え間違いを持ち込まない。
    private func todayWeekday() -> Int {
        return makeCalendar().component(Calendar.Component.weekday, from: now) - 1
    }

    /// 練習リマインドを**今日の曜日**に入れる。
    ///
    /// 組み替え曜日は必ず別の曜日にする —— 同じ日だと stale が優先されて
    /// 練習リマインドが消え、何を見ているのか分からないテストになる。
    /// (`setNotificationSettings` は `reshuffleWeekday` を書かない。§4.3 と共有の設定なので
    /// `setReshuffleWeekday` で別に入れる)
    private func enablePracticeReminder(_ db: SQLContext, at hour: Int, _ minute: Int = 0) throws {
        let repo = AppMetaRepository(db: db)
        try repo.setReshuffleWeekday((todayWeekday() + 1) % 7)
        try repo.setNotificationSettings(NotificationSettings(isEnabled: true,
                                                              practiceWeekdays: [todayWeekday()],
                                                              practiceHour: hour,
                                                              practiceMinute: minute,
                                                              eveningHour: 20,
                                                              eveningMinute: 0))
    }

    /// 練習リマインドは使わず、夜の通知(大会の振り返り)だけを見る設定。
    private func enableEveningOnly(_ db: SQLContext) throws {
        let repo = AppMetaRepository(db: db)
        try repo.setReshuffleWeekday((todayWeekday() + 1) % 7)
        try repo.setNotificationSettings(NotificationSettings(isEnabled: true,
                                                              practiceWeekdays: [Int](),
                                                              practiceHour: 18,
                                                              practiceMinute: 0,
                                                              eveningHour: 20,
                                                              eveningMinute: 0))
    }

    private func dates(_ planned: [PlannedNotification], of kind: NotificationKind) -> [Date] {
        var result: [Date] = []
        for notification in planned {
            if notification.kind == kind {
                result.append(notification.date)
            }
        }
        return result
    }

    private func contains(_ planned: [PlannedNotification], _ kind: NotificationKind, at date: Date) -> Bool {
        for candidate in dates(planned, of: kind) {
            if candidate == date {
                return true
            }
        }
        return false
    }

    // MARK: - オフならオフ(§8 既定は off)

    /// **許可を求める前に勝手に鳴らさない。** 大会が控えていても 1 件も返さない。
    func testReturnsNothingWhenDisabled() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        _ = try CompetitionRepository(db: db).create(name: "県大会", eventDate: day(3, at: 9))

        XCTAssertEqual(0, try makeService(db).plannedNotifications(now: now).count)
    }

    /// 初期状態(何も設定していない DB)でも空。
    func testReturnsNothingOnAFreshDatabase() throws {
        let db = try makeDatabase()
        defer { try? db.close() }

        XCTAssertEqual(0, try makeService(db).plannedNotifications(now: now).count)
    }

    /// 上の 2 つが「そもそも予定が無いから空」で通っていないことを示す。
    /// **オンにすると同じ DB から予定が出る。**
    func testEnablingProducesNotifications() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        _ = try CompetitionRepository(db: db).create(name: "県大会", eventDate: day(3, at: 9))
        try enableEveningOnly(db)

        XCTAssertTrue(try makeService(db).plannedNotifications(now: now).count > 0)
    }

    // MARK: - 過ぎた時刻には登録しない

    /// 13 時に開いたとき、**今日の 8 時の分は登録しない**(過去に予約すると即座に鳴る)。
    /// 来週の同じ曜日の分は残る —— 「今日の 1 件だけ落ちる」ことまで見る。
    func testSkipsTodaysReminderWhenItsTimeHasPassed() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        try enablePracticeReminder(db, at: 8)

        let planned = try makeService(db).plannedNotifications(now: now)

        XCTAssertFalse(contains(planned, .practiceReminder, at: day(0, at: 8)))
        XCTAssertTrue(contains(planned, .practiceReminder, at: day(7, at: 8)))
    }

    /// まだ来ていない時刻は残す。
    func testKeepsTodaysReminderWhenItsTimeIsAhead() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        try enablePracticeReminder(db, at: 18, 30)

        let planned = try makeService(db).plannedNotifications(now: now)

        XCTAssertTrue(contains(planned, .practiceReminder, at: day(0, at: 18, 30)))
    }

    /// ちょうど今の時刻は登録しない(判定は `>` であって `>=` ではない)。
    func testSkipsAReminderAtExactlyNow() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        try enablePracticeReminder(db, at: 13)

        let planned = try makeService(db).plannedNotifications(now: now)

        XCTAssertFalse(contains(planned, .practiceReminder, at: day(0, at: 13)))
    }

    // MARK: - 大会は DB から拾う

    /// 登録した大会の当日夜に振り返りの通知が入る。
    func testUsesCompetitionsFromTheDatabase() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        _ = try CompetitionRepository(db: db).create(name: "県大会", eventDate: day(3, at: 9))
        try enableEveningOnly(db)

        let planned = try makeService(db).plannedNotifications(now: now)

        XCTAssertEqual([day(3, at: 20)], dates(planned, of: .competitionReview))
    }

    /// **朝から出ている大会の、今夜の振り返りを落とさない。**
    ///
    /// 大会を探す基準は「今」ではなく**今日の 0 時**(`startOfDay`)。
    /// 「今」にすると、9 時開始の大会は 13 時に開いた時点で終了扱いになり、
    /// **その日の夜の振り返り通知が永久に出なくなる** —— 大会当日は一度きりなので、
    /// 逃すと振り返りが書かれないまま終わる。
    func testIncludesTonightsReviewForACompetitionEarlierToday() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        _ = try CompetitionRepository(db: db).create(name: "県大会", eventDate: day(0, at: 9))
        try enableEveningOnly(db)

        let planned = try makeService(db).plannedNotifications(now: now)

        XCTAssertEqual([day(0, at: 20)], dates(planned, of: .competitionReview))
    }

    /// 終わった大会には出さない。
    func testIgnoresFinishedCompetitions() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        _ = try CompetitionRepository(db: db).create(name: "去年の大会", eventDate: day(-7, at: 9))
        try enableEveningOnly(db)

        let planned = try makeService(db).plannedNotifications(now: now)

        XCTAssertEqual(0, dates(planned, of: .competitionReview).count)
    }

    /// **先の分まで際限なく入れない。** `fetchUpcoming` は先の大会をすべて返すが、
    /// 登録するのは 21 日先まで(起動のたびに入れ直すので足りる)。
    func testDoesNotScheduleBeyondThreeWeeks() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        _ = try CompetitionRepository(db: db).create(name: "遠い大会", eventDate: day(30, at: 9))
        try enableEveningOnly(db)

        let planned = try makeService(db).plannedNotifications(now: now)

        XCTAssertEqual(0, dates(planned, of: .competitionReview).count)
    }
}
