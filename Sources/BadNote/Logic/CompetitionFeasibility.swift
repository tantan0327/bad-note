import Foundation

/// 「この大会では厳しいかもしれません」の判定(§7.5)。
///
/// **控えめに提示する。** アプリは解釈や警告を出さず、判断材料を置くだけ。
/// 判断するのは本人。
///
/// 純粋関数。
public struct CompetitionFeasibility {
    private init() {
    }

    /// 習得コストごとの目安の日数。
    ///
    /// §3.4 の「コスト 3 は大会に間に合わない可能性があり、シーズン単位の課題として扱う」に
    /// 合わせて、3 を 90 日(ほぼ 1 シーズン)としている。**あくまで目安。**
    public static func requiredDays(forCost cost: Int) -> Int {
        switch cost {
        case 1: return 7
        case 2: return 30
        default: return 90
        }
    }

    /// 残り時間に対してコストが重いか。
    ///
    /// - コスト未設定なら **false**。判断材料が無いのに厳しいとは言わない
    /// - 大会が過ぎていれば false
    /// - 必要日数ちょうどは厳しくない扱い
    public static func isTight(cost: Int?, remainingDays: Int) -> Bool {
        guard let cost = cost else {
            return false
        }
        if remainingDays < 0 {
            return false
        }
        return remainingDays < CompetitionFeasibility.requiredDays(forCost: cost)
    }
}
