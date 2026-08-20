import Foundation

/// 残り練習回数の推定(§5.2「残り日数 × 直近の平均練習頻度」)。
///
/// 純粋関数。Repository も現在時刻も持たず、渡された値だけで結果が決まる。
/// 同じ入力なら常に同じ出力になるので、境界条件をテストで固定できる。
public struct PracticeForecast {
    private init() {
    }

    private static let secondsPerDay = 86_400.0

    /// 直近の練習の平均間隔(日)。**推定できないときは nil。**
    ///
    /// n 件の練習が作る間隔は n-1 個なので、最古と最新の期間を n-1 で割る。
    /// 渡す順番には依存しない。
    ///
    /// - 練習が 1 件以下 → 間隔が 1 つも作れないので nil
    /// - 全部同じ日 → 期間が 0 でゼロ除算になるので nil
    public static func averageIntervalDays(practiceDates: [Date]) -> Double? {
        if practiceDates.count < 2 {
            return nil
        }

        var earliest = practiceDates[0].timeIntervalSince1970
        var latest = earliest
        for date in practiceDates {
            let seconds = date.timeIntervalSince1970
            if seconds < earliest {
                earliest = seconds
            }
            if seconds > latest {
                latest = seconds
            }
        }

        let spanDays = (latest - earliest) / PracticeForecast.secondsPerDay
        if spanDays <= 0.0 {
            return nil
        }
        return spanDays / Double(practiceDates.count - 1)
    }

    /// 大会までの残り練習回数。**推定できないときは nil。**
    ///
    /// §7.1「あと 42日 / 12回」の 12 の方。日数より行動に直結する数字(§5.2)。
    ///
    /// 戻り値の nil と 0 は意味が違う。
    /// - **nil** = 履歴が足りず頻度を出せない。呼び出し側は残り日数だけ見せる
    /// - **0** = 大会が過ぎた / 残り日数が平均間隔に届かない。確定した 0
    ///
    /// 履歴なしで 0 を返さないのは、0 回が「もう間に合わない」に読めてしまうため
    /// (§5 モチベーション設計。使い始めの人ほど履歴が無い)。
    /// 大会日が過ぎているときだけは履歴に関係なく 0 —— 確定した事実が推定に優先する。
    ///
    /// 端数は切り捨てる。多めに言って裏切らない。
    public static func remainingPracticeCount(practiceDates: [Date],
                                              eventDate: Date,
                                              asOf: Date) -> Int? {
        let remainingDays = eventDate.timeIntervalSince(asOf) / PracticeForecast.secondsPerDay
        if remainingDays <= 0.0 {
            return 0
        }
        guard let intervalDays = PracticeForecast.averageIntervalDays(practiceDates: practiceDates) else {
            return nil
        }
        return Int(remainingDays / intervalDays)
    }
}
