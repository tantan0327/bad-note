import Foundation

/// 練習予定日から残り練習回数を出す(§5.2)。
///
/// **推定しない。** 以前は練習履歴の平均間隔から `残り日数 / 平均間隔` を計算していたが、
/// 「直近」の窓が無く、使い始めの頻度が一生効き続けて実際とずれた。
/// 本人が決めた予定日を数えれば実数になる。
///
/// **nil と 0 は意味が違う。**
/// - `nil` = 予定日をまだ決めていない。**回数を出さない**(根拠のない数字を出さない)
/// - `0` = 決めた上で、この大会までには 1 日も無い。事実なので出してよい
///
/// 未設定で 0 を返さないのは、**0 回が「もう間に合わない」に読めてしまう**ため
/// (§5 モチベーション設計。使い始めの人ほど何も登録していない)。
/// 大会が過ぎているときだけは予定に関係なく 0 —— 確定した事実が優先する。
///
/// 純粋関数。DB も現在時刻も見ない。
public struct PracticePlan {
    private init() {
    }

    /// まとめて追加で一度に作れる日数の上限(暴走防止)。
    public static let maxSpanDays = 366

    /// 大会までに残っている予定日の数。**予定が 1 日も無ければ nil。**
    ///
    /// 数える区間は **`[asOf の暦日 0 時, 大会当日 0 時)`** の半開区間。
    ///
    /// - **今日は数える** —— 「あと 42日」が今日を 0 日目として数えるので、
    ///   同じカードの 2 つの数字が別の暦を使わないようにする
    /// - **大会当日は数えない** —— 準備に使えるのは前日まで。
    ///   まとめて追加の既定期間(〜大会の前日)と揃える
    public static func remainingCount(planDays: [Date],
                                      eventDate: Date,
                                      asOf: Date,
                                      calendar: Calendar = Calendar.current) -> Int? {
        // 「予定が無いなら回数を出さない」を例外なしの 1 文にするため最初に置く
        if planDays.isEmpty {
            return nil
        }
        let start = calendar.startOfDay(for: asOf)
        let end = calendar.startOfDay(for: eventDate)
        if end <= start {
            return 0
        }
        var count = 0
        for planDay in planDays {
            let day = calendar.startOfDay(for: planDay)
            if day >= start && day < end {
                count += 1
            }
        }
        return count
    }

    /// 曜日と期間から個別の日付を作る。**両端を含む。**
    ///
    /// 数え上げが半開区間なのに対してこちらが閉区間なのは意図的 ——
    /// 利用者が選んだ終端の日が生成されないのは驚きになる。
    ///
    /// 曜日は **0 = 日曜 ... 6 = 土曜**(`reshuffleWeekday` と同じ規約)。
    /// 返す日はすべてその日の 0 時で、昇順・重複なし。
    public static func dates(weekdays: [Int],
                             from: Date,
                             through: Date,
                             calendar: Calendar = Calendar.current) -> [Date] {
        var result: [Date] = []
        if weekdays.isEmpty {
            return result
        }
        let start = calendar.startOfDay(for: from)
        let end = calendar.startOfDay(for: through)
        if end < start {
            return result
        }
        var current = start
        var guardCount = 0
        while current <= end && guardCount < PracticePlan.maxSpanDays {
            // Calendar の weekday は 1 = 日曜。設定は 0 = 日曜
            let weekday = calendar.component(Calendar.Component.weekday, from: current) - 1
            if PracticePlan.contains(weekdays, weekday) {
                result.append(current)
            }
            guardCount += 1
            // 1 日ずつ足すのは暦に任せる(86,400 秒加算は夏時間でずれる)
            guard let next = calendar.date(byAdding: Calendar.Component.day, value: 1, to: current) else {
                return result
            }
            current = next
        }
        return result
    }

    private static func contains(_ weekdays: [Int], _ weekday: Int) -> Bool {
        for candidate in weekdays {
            if candidate == weekday {
                return true
            }
        }
        return false
    }
}
