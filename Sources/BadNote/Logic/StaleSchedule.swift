import Foundation

/// stale 判定をいつ実行するかの判断(§4.3)。
///
/// **週 1 回だけ。** 毎日出すと無視されるようになる。
///
/// 純粋関数。実際の実行は `StaleEvaluator` が行う。
public struct StaleSchedule {
    private init() {
    }

    /// 曜日に関係なく実行する間隔(取りこぼし救済)。
    public static let rescueDays = 7

    /// 今日、評価を実行すべきか。
    ///
    /// - 一度も評価していなければ実行する
    /// - 組み替えの曜日で、前回の評価が今日より前なら実行する
    /// - 前回から `rescueDays` 日以上経っていれば曜日に関係なく実行する
    ///
    /// - Parameter reshuffleWeekday: 0 = 日曜 ... 6 = 土曜。
    public static func shouldEvaluate(today: Date,
                                      lastEvaluatedAt: Date?,
                                      reshuffleWeekday: Int,
                                      calendar: Calendar = Calendar.current) -> Bool {
        guard let lastEvaluatedAt = lastEvaluatedAt else {
            return true
        }

        let startOfToday = calendar.startOfDay(for: today)
        // 同じ日に 2 回は走らせない(起動のたびに評価しない)
        if lastEvaluatedAt >= startOfToday {
            return false
        }

        let elapsedDays = today.timeIntervalSince(lastEvaluatedAt) / 86_400.0
        if elapsedDays >= Double(StaleSchedule.rescueDays) {
            return true
        }

        // Calendar の weekday は 1 = 日曜。app_meta は 0 = 日曜
        let weekday = calendar.component(Calendar.Component.weekday, from: today) - 1
        return weekday == reshuffleWeekday
    }
}
