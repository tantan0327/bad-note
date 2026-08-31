import Foundation
import SkipSQL
#if canImport(UserNotifications)
import UserNotifications
#else
import SkipUI
#endif

/// 通知の登録(§8)。
///
/// **1 日 1 通まで。** どれを出すかは `NotificationPlan`(純粋関数)が決め、
/// ここは許可の取得と OS への登録だけを行う。
///
/// 先の予定を毎回まとめて入れ直す方式にしている。繰り返しトリガーだと
/// 「大会当日は練習リマインドを出さない」といった 1 日 1 通の制御ができない。
public final class NotificationService {

    /// 何日先まで登録するか。起動のたびに入れ直すので長すぎなくてよい。
    public static let scheduledDays = 21

    private let db: SQLContext
    private let calendar: Calendar

    public init(db: SQLContext, calendar: Calendar = Calendar.current) {
        self.db = db
        self.calendar = calendar
    }

    /// 通知の許可を求める。既に決まっていれば OS が黙って結果を返す。DB は使わない。
    @discardableResult
    public static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    /// 何を通知するかを DB から組み立てる。**同期。呼び出し側の接続をそのまま使う。**
    ///
    /// DB を使う部分と OS に登録する部分を分けているのは、
    /// 非同期の中で別の接続を開くと `database is locked` になるため。
    public func plannedNotifications(now: Date = Date()) throws -> [PlannedNotification] {
        let settings = try AppMetaRepository(db: db).notificationSettings()
        if !settings.isEnabled {
            return []
        }

        // 基準は「今」ではなく**今日の 0 時**。「今」にすると午前中に始まった大会が
        // 昼の時点で終了扱いになり、その日の夜の振り返り通知が出なくなる
        let today = calendar.startOfDay(for: now)

        var competitionDates: [Date] = []
        for competition in try CompetitionRepository(db: db).fetchUpcoming(asOf: today) {
            competitionDates.append(competition.eventDate)
        }

        // §5.2 練習前の通知は**登録された練習予定日**に出す(曜日ではない)。
        // 予定日を 1 日も入れていなければ、練習前の通知は出ない
        var practicePlanDates: [Date] = []
        for planDay in try PracticePlanRepository(db: db).fetchUpcoming(asOf: today) {
            practicePlanDates.append(planDay.date)
        }

        var upcoming: [PlannedNotification] = []
        for notification in NotificationPlan.plan(from: now,
                                                  days: NotificationService.scheduledDays,
                                                  settings: settings,
                                                  practicePlanDates: practicePlanDates,
                                                  competitionDates: competitionDates,
                                                  calendar: calendar) {
            // 過ぎた時刻には登録しない
            if notification.date > now {
                upcoming.append(notification)
            }
        }
        return upcoming
    }

    /// 組み立てた予定を OS に登録する。**DB は触らない。**
    ///
    /// 毎回すべて入れ直す。繰り返しトリガーだと
    /// 「大会当日は練習リマインドを出さない」といった 1 日 1 通の制御ができない。
    public static func apply(_ planned: [PlannedNotification], calendar: Calendar = Calendar.current) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        for notification in planned {
            do {
                try await NotificationService.add(notification, calendar: calendar)
            } catch {
                // 1 件登録できなくても残りは続ける
            }
        }
    }

    private static func add(_ notification: PlannedNotification, calendar: Calendar) async throws {
        let content = UNMutableNotificationContent()
        content.title = NotificationService.title(for: notification.kind)
        content.body = NotificationService.body(for: notification.kind)

        var components = calendar.dateComponents([Calendar.Component.year,
                                                  Calendar.Component.month,
                                                  Calendar.Component.day,
                                                  Calendar.Component.hour,
                                                  Calendar.Component.minute],
                                                 from: notification.date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let identifier = notification.kind.rawValue + "-" + String(Int(notification.date.timeIntervalSince1970))
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try await UNUserNotificationCenter.current().add(request)
    }

    static func title(for kind: NotificationKind) -> String {
        switch kind {
        case .practiceReminder: return "今週の重点"
        case .competitionReview: return "大会おつかれさまでした"
        case .staleReview: return "しばらく触れていない課題"
        }
    }

    static func body(for kind: NotificationKind) -> String {
        switch kind {
        case .practiceReminder: return "今日の練習で意識する 3 つを確認しましょう"
        case .competitionReview: return "うまくいったことと、次にやることを書き留めておきませんか"
        case .staleReview: return "触れていない課題があります。重点に戻すか決めましょう"
        }
    }
}
