import Foundation

/// 手応えの向き(§3.2)。
public enum MasteryDirection: String, Hashable, Sendable {
    /// できた が続いている —— 前に進んでいる
    case forward
    /// 中立 —— 近づいた だけ / 未入力 / 記録なし
    case steady
    /// 次にやる が続いている —— 仕切り直している
    case restart
}

/// 直近の手応えの向きと連続回数(§3.2)。
///
/// **3 つの言葉に 3 つの違う意味を持たせるのはここ 1 か所。**
///
/// | 手応え | 意味 | 連続への効き方 |
/// |---|---|---|
/// | できた | 前に進む | 数える |
/// | **近づいた** | **止まらない** | **数えないが、切りもしない**(中立) |
/// | 次にやる | 仕切り直し | 逆向きに数える |
///
/// それまで `closer` と `next` はコード上まったく同じ扱い(`done` の連続を切るだけ)で、
/// どちらを付けても結果が変わらなかった。「近づいた」は前進なのだから、
/// 積み上げたものを戻さない。
///
/// 純粋関数。DB も現在時刻も見ない。
public struct MasteryTrend: Hashable, Sendable {
    public let direction: MasteryDirection
    /// 直近の連続回数。
    ///
    /// **画面には出さない**(§5.3)。数字を出すと、途切れた瞬間に 0 に落ちる体験になり、
    /// 実装しないと決めたストリークと同じものになる。画面に出すのは向きだけ。
    public let count: Int

    /// 提案に必要な連続回数。**昇格・戻す・克服の 3 つが同じ数を読む。**
    public static let requiredStreak = 3

    public static let steady = MasteryTrend(direction: MasteryDirection.steady, count: 0)

    public init(direction: MasteryDirection, count: Int) {
        self.direction = direction
        self.count = count
    }

    /// 直近の向きと連続回数。`recentResults` は**新しい順**(先頭が最新)。
    ///
    /// - `closer` と `nil` は飛ばす(中立)
    /// - `done` と `next` は互いに打ち切る
    /// - 完全に対称 —— 片方だけ直すバグが起きないよう、同じ 1 本のループで扱う
    public static func of(recentResults: [FocusResult?]) -> MasteryTrend {
        var direction = MasteryDirection.steady
        var count = 0
        for result in recentResults {
            guard let result = result else {
                continue
            }
            if result == FocusResult.closer {
                continue
            }
            let current = result == FocusResult.done ? MasteryDirection.forward : MasteryDirection.restart
            if count == 0 {
                direction = current
                count = 1
            } else if current == direction {
                count += 1
            } else {
                break
            }
        }
        return MasteryTrend(direction: direction, count: count)
    }
}
