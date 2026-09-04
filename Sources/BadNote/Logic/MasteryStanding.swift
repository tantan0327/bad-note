import Foundation

/// 本人に聞く 1 手の種類(§3.2)。
public enum MasteryOfferKind: String, Hashable, Sendable {
    /// 1 つ上げますか?
    case levelUp
    /// 1 つ戻しますか?
    case stepDown
    /// 「克服した」への扉(問いではない)
    case overcome
}

/// 本人に聞く 1 手。
///
/// **関連値つき enum にしない** —— このリポジトリに 1 つも無く、
/// Skip での扱いも重い。`XCTAssertEqual` も書きづらい。
public struct MasteryOffer: Hashable, Sendable {
    public let kind: MasteryOfferKind
    /// 提案先のレベル。`overcome` では現在のレベル(Lv.4)。
    public let level: MasteryLevel

    public init(kind: MasteryOfferKind, level: MasteryLevel) {
        self.kind = kind
        self.level = level
    }
}

/// 課題の「今どこにいるか」(§3.2 / §7.2 / §7.3)。
///
/// **画面に出す文と、提案を出す判定はこの値から作る。**
/// 別々に数えると「進んでいます」と出ているのに提案が出ない、が起きる。
///
/// 手応えを付けても何も変わらない、という状態を解消するための型 ——
/// できた / 近づいた / 次にやる のそれぞれが、ここを通って画面に出る。
///
/// 純粋関数。DB も現在時刻も見ない。
public struct MasteryStanding: Hashable, Sendable {
    public let level: MasteryLevel
    public let trend: MasteryTrend
    /// 本人に聞く 1 手。ふつうは nil。
    public let offer: MasteryOffer?

    public init(level: MasteryLevel, trend: MasteryTrend, offer: MasteryOffer?) {
        self.level = level
        self.trend = trend
        self.offer = offer
    }

    /// 断った記録と状態を見る版。**画面はこちらを使う。**
    public static func of(recentResults: [FocusResult?], issue: Issue) -> MasteryStanding {
        let base = MasteryStanding.of(recentResults: recentResults, level: issue.masteryLevel)
        // 克服済みには何も出さない。梯子は登り切っている
        if issue.status == IssueStatus.archived {
            return MasteryStanding(level: base.level, trend: base.trend, offer: nil)
        }
        guard let offer = base.offer else {
            return base
        }
        // §3.2 同じ段で一度断られていれば、もう聞かない。
        // **上げるのを断ったことが、戻す提案まで黙らせない**ように列を分けてある
        if offer.kind == MasteryOfferKind.levelUp,
           let declined = issue.levelUpDeclinedLevel, declined == issue.masteryLevel.rawValue {
            return MasteryStanding(level: base.level, trend: base.trend, offer: nil)
        }
        if offer.kind == MasteryOfferKind.stepDown,
           let declined = issue.stepDownDeclinedLevel, declined == issue.masteryLevel.rawValue {
            return MasteryStanding(level: base.level, trend: base.trend, offer: nil)
        }
        return base
    }

    /// 閾値と端だけを見る版。
    ///
    /// **`offer` は 1 つの分岐で決める。** 向きが 1 つしか無いので、
    /// 上げると戻すが同時に立つことは構造的に起きない。
    public static func of(recentResults: [FocusResult?], level: MasteryLevel) -> MasteryStanding {
        let trend = MasteryTrend.of(recentResults: recentResults)
        return MasteryStanding(level: level,
                               trend: trend,
                               offer: MasteryStanding.offer(trend: trend, level: level))
    }

    private static func offer(trend: MasteryTrend, level: MasteryLevel) -> MasteryOffer? {
        if trend.count < MasteryTrend.requiredStreak {
            return nil
        }
        if trend.direction == MasteryDirection.forward {
            guard let next = MasteryLevel(rawValue: level.rawValue + 1) else {
                // 上が無い = Lv.4。ここまで来たら克服の扉を開ける(§7.3)
                return MasteryOffer(kind: MasteryOfferKind.overcome, level: level)
            }
            return MasteryOffer(kind: MasteryOfferKind.levelUp, level: next)
        }
        if trend.direction == MasteryDirection.restart {
            guard let previous = MasteryLevel(rawValue: level.rawValue - 1) else {
                // 下が無い = Lv.1。戻す先が無いので何も言わない
                return nil
            }
            return MasteryOffer(kind: MasteryOfferKind.stepDown, level: previous)
        }
        return nil
    }
}
