import Foundation

/// 調整期の判定(§4.4 / §7.5)。
///
/// 目標大会の直前に、忘れていた課題を掘り返さないための期間。調整期の間は
/// stale の**評価自体をスキップ**し、ホームの「しばらく触れていない課題」も隠す(§4.4)。
///
/// **種目ごとに独立させない。** ホームの表示切り替え(8 週間)は種目ごとだが、
/// 調整期だけは「最も近い目標大会」を基準に全体で 1 つ(§7.5)。シングルスが調整期なら
/// ダブルスの課題も掘り返さない —— 直前に意識を散らさないための期間なので、
/// 種目で分けると意味が無くなる。
///
/// 純粋関数。
public struct AdjustmentPeriod {
    private init() {
    }

    private static let secondsPerDay = 86_400.0

    /// 大会の何日前から調整期に入るか(§4.4)。
    public static let standardLeadDays = 14

    /// 調整期に入っているか。
    ///
    /// 目標大会が 1 件も無ければ調整期ではない(大会なしでもアプリは成立する)。
    ///
    /// - **大会当日は調整期。** 残り 0 日も「2 週間前以内」に含む
    /// - **過ぎた大会は調整期を作らない。** 終わった大会は候補から外す。
    ///   目標大会が全部過去なら調整期は明ける(stale の提示を再開する)
    ///
    /// 当日をいつまで「当日」とみなすかは `asOf` の渡し方で決まる。今日の 0 時を渡せば
    /// 当日いっぱい調整期になる(`CompetitionRepository.fetchUpcoming(asOf:)` と同じ扱い)。
    ///
    /// - Parameter targets: 種目ごとの目標大会。順番は問わない。
    public static func isActive(targets: [Competition],
                                asOf: Date,
                                leadDays: Int = AdjustmentPeriod.standardLeadDays) -> Bool {
        guard let nearest = AdjustmentPeriod.nearestTarget(targets, asOf: asOf) else {
            return false
        }
        let remainingDays = nearest.eventDate.timeIntervalSince(asOf) / AdjustmentPeriod.secondsPerDay
        return remainingDays <= Double(leadDays)
    }

    /// 最も近い目標大会。過ぎた大会は含まない。1 件も残っていなければ nil。
    ///
    /// §7.5 の調整期の帯に大会名を出すときにも使う。
    public static func nearestTarget(_ targets: [Competition], asOf: Date) -> Competition? {
        var nearest: Competition? = nil
        var nearestRemaining = 0.0
        for target in targets {
            let remaining = target.eventDate.timeIntervalSince(asOf)
            if remaining < 0.0 {
                continue
            }
            if nearest == nil || remaining < nearestRemaining {
                nearest = target
                nearestRemaining = remaining
            }
        }
        return nearest
    }
}
