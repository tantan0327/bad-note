import Foundation

/// めざす姿を書くよう促すかの判定(§7.1)。
///
/// **初回は促さない。数回使った後に 1 度だけ促す。**
/// 使い始めに「まず理想像を書いてください」と出しても書けなくて止まるだけで、
/// 練習を数回記録した後の方が言葉にしやすい。
///
/// 純粋関数。
public struct VisionPrompt {
    private init() {
    }

    /// これだけ練習を記録してから促す。
    public static let requiredPracticeCount = 3

    /// 促すべきか。
    ///
    /// - 既に書いてあれば促さない(画像だけでも書いてあるとみなす)
    /// - 一度促していれば二度と促さない。無視されたものを蒸し返さない
    /// - 練習の記録が `requiredPracticeCount` 回に届くまでは促さない
    public static func shouldPrompt(vision: Vision,
                                    practiceCount: Int,
                                    alreadyPrompted: Bool,
                                    requiredPracticeCount: Int = VisionPrompt.requiredPracticeCount) -> Bool {
        if !vision.isEmpty {
            return false
        }
        if alreadyPrompted {
            return false
        }
        return practiceCount >= requiredPracticeCount
    }
}
