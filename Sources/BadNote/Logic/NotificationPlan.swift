import Foundation

/// 通知の種類(§8)。
public enum NotificationKind: String, CaseIterable, Hashable, Sendable {
    /// 練習開始前 —— 今週の重点 3 つ
    case practiceReminder = "practice_reminder"
    /// 大会当日の夜 —— 振り返りを促す
    case competitionReview = "competition_review"
    /// 週 1 回(組み替えの曜日)—— しばらく触れていない課題
    case staleReview = "stale_review"
}

/// 通知の設定(§8)。曜日は 0 = 日曜 ... 6 = 土曜。
public struct NotificationSettings: Hashable, Sendable {
    /// **既定は off。** 許可を求める前に勝手に鳴らさない。
    public var isEnabled: Bool
    /// 練習開始前の時刻(時)
    public var practiceHour: Int
    /// 練習開始前の時刻(分)。2.5 で「時:分」指定にした
    public var practiceMinute: Int
    /// 夜の通知(大会の振り返り / stale)の時刻(時)
    public var eveningHour: Int
    /// 夜の通知の時刻(分)
    public var eveningMinute: Int
    /// 組み替えの曜日(§4.3 の `reshuffle_weekday` と揃える)
    public var reshuffleWeekday: Int

    public init(isEnabled: Bool = false,
                practiceHour: Int = 18,
                practiceMinute: Int = 0,
                eveningHour: Int = 20,
                eveningMinute: Int = 0,
                reshuffleWeekday: Int = 0) {
        self.isEnabled = isEnabled
        self.practiceHour = practiceHour
        self.practiceMinute = practiceMinute
        self.eveningHour = eveningHour
        self.eveningMinute = eveningMinute
        self.reshuffleWeekday = reshuffleWeekday
    }

    public static let standard = NotificationSettings()
}

/// 予定された通知 1 件。
public struct PlannedNotification: Hashable, Sendable {
    public let kind: NotificationKind
    public let date: Date

    public init(kind: NotificationKind, date: Date) {
        self.kind = kind
        self.date = date
    }
}

/// いつ何を通知するかの計画(§8)。
///
/// **1 日 1 通まで。** 通知過多でオフにされると、忘れ防止の仕組みごと機能しなくなる。
/// 同じ日に複数該当したときは 1 つに絞る。
///
/// 純粋関数。実際の登録は `NotificationService` が行う。
public struct NotificationPlan {
    private init() {
    }

    /// その日に出す通知。無ければ nil。
    ///
    /// 重なったときの優先は **大会 > stale > 練習リマインド**。
    /// - 大会当日は一度きりで、逃すと振り返りが書かれない
    /// - stale は週 1 回だけの機会
    /// - 練習リマインドは毎週来るので、1 回飛んでも影響が小さい
    public static func notification(on day: Date,
                                    settings: NotificationSettings,
                                    isPracticeDay: Bool,
                                    isCompetitionDay: Bool,
                                    calendar: Calendar = Calendar.current) -> PlannedNotification? {
        if !settings.isEnabled {
            return nil
        }

        if isCompetitionDay {
            return NotificationPlan.at(hour: settings.eveningHour, minute: settings.eveningMinute, on: day, kind: .competitionReview, calendar: calendar)
        }

        // Calendar の weekday は 1 = 日曜。設定は 0 = 日曜
        let weekday = calendar.component(Calendar.Component.weekday, from: day) - 1
        if weekday == settings.reshuffleWeekday {
            return NotificationPlan.at(hour: settings.eveningHour, minute: settings.eveningMinute, on: day, kind: .staleReview, calendar: calendar)
        }
        if isPracticeDay {
            return NotificationPlan.at(hour: settings.practiceHour, minute: settings.practiceMinute, on: day, kind: .practiceReminder, calendar: calendar)
        }
        return nil
    }

    /// 今日から `days` 日分の計画。1 日あたり多くても 1 通。
    public static func plan(from start: Date,
                            days: Int,
                            settings: NotificationSettings,
                            practicePlanDates: [Date],
                            competitionDates: [Date],
                            calendar: Calendar = Calendar.current) -> [PlannedNotification] {
        if !settings.isEnabled {
            return []
        }
        var planned: [PlannedNotification] = []
        let startOfDay = calendar.startOfDay(for: start)
        for offset in 0..<days {
            guard let day = calendar.date(byAdding: Calendar.Component.day, value: offset, to: startOfDay) else {
                continue
            }
            // 大会と練習予定で**日の一致判定を同じ関数**にする(ずれると片方だけ鳴る)
            let isCompetitionDay = NotificationPlan.isSameDay(day, in: competitionDates, calendar: calendar)
            let isPracticeDay = NotificationPlan.isSameDay(day, in: practicePlanDates, calendar: calendar)
            if let notification = NotificationPlan.notification(on: day,
                                                                settings: settings,
                                                                isPracticeDay: isPracticeDay,
                                                                isCompetitionDay: isCompetitionDay,
                                                                calendar: calendar) {
                planned.append(notification)
            }
        }
        return planned
    }

    private static func at(hour: Int, minute: Int, on day: Date, kind: NotificationKind, calendar: Calendar) -> PlannedNotification? {
        var components = calendar.dateComponents([Calendar.Component.year, Calendar.Component.month, Calendar.Component.day], from: day)
        components.hour = hour
        components.minute = minute
        guard let date = calendar.date(from: components) else {
            return nil
        }
        return PlannedNotification(kind: kind, date: date)
    }

    private static func isSameDay(_ day: Date, in dates: [Date], calendar: Calendar) -> Bool {
        let target = calendar.startOfDay(for: day)
        for date in dates {
            if calendar.startOfDay(for: date) == target {
                return true
            }
        }
        return false
    }
}
