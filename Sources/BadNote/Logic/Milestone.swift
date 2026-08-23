import Foundation

/// 積み上げの「節目」(1.2 / モチベーション設計)。**到達済みだけを祝う。**
///
/// §5.3 の「目標値・ノルマを置かない」を守るため、これは前向きの目標ではなく
/// **後ろ向きの達成の記録**。次の節目までの残り(「あと N 時間」)や締め切りは出さない。
/// 到達した節目が並んでいくコレクションとして、自信の裏づけにする。
public enum Milestone {
    /// 節目(時間)。ここに到達したら祝う。最初を 1 時間にして早い達成感を作る。
    public static let hourThresholds: [Int] = [1, 5, 10, 25, 50, 100, 200, 500, 1000]

    /// 究極の目標 —— **1 万時間の法則**。節目の行の終端に北極星として常に示す。
    /// 到達までの残り時間や締め切りは出さない(§5.3)。目指す先を静かに見せるだけ。
    public static let ultimateHours = 10_000

    /// 通算(分)から、到達済みの節目(時間)を **小さい順** に返す(1 万時間は含めない)。
    public static func reachedHours(minutes: Int) -> [Int] {
        var result: [Int] = []
        for hours in hourThresholds {
            if minutes >= hours * 60 {
                result.append(hours)
            }
        }
        return result
    }

    /// 究極の目標(1 万時間)に到達したか。
    public static func hasReachedUltimate(minutes: Int) -> Bool {
        return minutes >= ultimateHours * 60
    }
}
