import Foundation

/// レベルアップ提案の判定(§3.2)。
///
/// **自動でレベルを上げない。** 判定するのはここまでで、実際に上げるかはユーザーが決める
/// (練習ログ保存時に「Lv.3 に上げますか?」と聞く)。
///
/// 純粋関数。手応え履歴と現在のレベルだけで決まる。
public struct LevelUpSuggestion {
    private init() {
    }

    /// 直近から数えた `done` の連続回数。
    ///
    /// `recentResults` は**新しい順**(先頭が最新)。
    /// 数え方は `MasteryTrend` に集約してある —— 昇格・戻す・克服が同じ 1 本を読むことで、
    /// 「進んでいます」と出ているのに提案が出ない、が起きないようにしている。
    ///
    /// - **`closer`(近づいた)は連続を切らない**(2026-09-04)。数えもしない中立。
    ///   「近づいた」は前進なので、積み上げたものを戻さない
    /// - **nil(未入力)も中立。** 手応えは未選択でも保存できる(§7.2)ので、
    ///   入力していないことを「できなかった」と解釈しない
    /// - `next`(次にやる)だけが打ち切る
    public static func consecutiveDoneCount(recentResults: [FocusResult?]) -> Int {
        let trend = MasteryTrend.of(recentResults: recentResults)
        return trend.direction == MasteryDirection.forward ? trend.count : 0
    }

    /// 課題の状態を見て提案すべきレベルを返す。提案しないときは nil。
    ///
    /// §3.2「1 度だけ提案する」—— 同じレベルで一度断られていれば、もう聞かない。
    /// レベルが変われば `levelUpDeclinedLevel` と一致しなくなるので、また提案できる。
    public static func suggestedLevel(recentResults: [FocusResult?], for issue: Issue) -> MasteryLevel? {
        let standing = MasteryStanding.of(recentResults: recentResults, issue: issue)
        guard let offer = standing.offer, offer.kind == MasteryOfferKind.levelUp else {
            return nil
        }
        return offer.level
    }

    /// 提案すべきレベル。提案しないときは nil。
    ///
    /// `done` が 3 回連続していれば 1 つ上のレベルを返す。
    /// Lv.4(試合)は上限なので、連続していても nil —— 上げ先が無いことが
    /// そのまま「提案しない」になる。
    ///
    /// **「1 度だけ提案する」の制御はここではできない。** 提案を断られても履歴は
    /// 変わらないので、この関数は次も同じ答えを返す。提案済みかどうかは呼び出し側で
    /// 持つこと(§3.2)。
    public static func suggestedLevel(recentResults: [FocusResult?],
                                      currentLevel: MasteryLevel) -> MasteryLevel? {
        guard let nextLevel = MasteryLevel(rawValue: currentLevel.rawValue + 1) else {
            return nil
        }
        if LevelUpSuggestion.consecutiveDoneCount(recentResults: recentResults) < MasteryTrend.requiredStreak {
            return nil
        }
        return nextLevel
    }
}
