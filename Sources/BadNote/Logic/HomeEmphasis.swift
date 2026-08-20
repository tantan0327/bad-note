import Foundation

/// ホームで大きく出す数字の切り替え(§5.1)。
///
/// 目標大会の 8 週間前を境に入れ替える。同じデータで見せ方だけ変える。
/// 遠い時期に残り日数を大きく出すと「まだ先だ」になり、逆効果になるため。
///
/// **切り替えは種目ごとに独立**(§7.5)。全体で 1 つに揃えるのは調整期の判定だけ。
public enum HomeEmphasis: Hashable {
    /// 8 週間より前。今月の練習時間 / レベルアップ回数を大きく、残り日数を小さく添える。
    case buildUp
    /// 8 週間以内。残り日数 / 残り練習回数を大きく、積み上げを小さく添える。
    case countdown

    /// 切り替えの境目(8 週間)。
    public static let switchDays = 56

    private static let secondsPerDay = 86_400.0

    /// 目標大会の日付から、どちらを大きく出すかを決める。
    ///
    /// 目標大会が無い場合と、過ぎている場合は積み上げ側。
    /// カウントダウンする先が無いのに日数を出しても意味がない。
    public static func forEvent(_ eventDate: Date?, asOf: Date, switchDays: Int = HomeEmphasis.switchDays) -> HomeEmphasis {
        guard let eventDate = eventDate else {
            return HomeEmphasis.buildUp
        }
        let remainingDays = eventDate.timeIntervalSince(asOf) / HomeEmphasis.secondsPerDay
        if remainingDays < 0.0 {
            return HomeEmphasis.buildUp
        }
        return remainingDays <= Double(switchDays) ? HomeEmphasis.countdown : HomeEmphasis.buildUp
    }
}
