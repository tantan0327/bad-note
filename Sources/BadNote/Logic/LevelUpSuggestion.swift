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

    /// 提案に必要な `done` の連続回数(§3.2)。
    private static let requiredStreak = 3

    /// 直近から数えた `done` の連続回数。
    ///
    /// `recentResults` は**新しい順**(先頭が最新)。
    ///
    /// - `closer` / `next` が出たらそこで打ち切る
    /// - **nil(未入力)は連続を切らない。** 数にも入れず、飛ばして次を見る。
    ///   手応えは未選択でも練習ログを保存できる(§7.2)ので、入力していないことを
    ///   「できなかった」と解釈しない
    public static func consecutiveDoneCount(recentResults: [FocusResult?]) -> Int {
        var count = 0
        for result in recentResults {
            guard let result = result else {
                continue
            }
            if result == FocusResult.done {
                count += 1
            } else {
                break
            }
        }
        return count
    }

    /// 課題の状態を見て提案すべきレベルを返す。提案しないときは nil。
    ///
    /// §3.2「1 度だけ提案する」—— 同じレベルで一度断られていれば、もう聞かない。
    /// レベルが変われば `levelUpDeclinedLevel` と一致しなくなるので、また提案できる。
    public static func suggestedLevel(recentResults: [FocusResult?], for issue: Issue) -> MasteryLevel? {
        if let declined = issue.levelUpDeclinedLevel, declined == issue.masteryLevel.rawValue {
            return nil
        }
        return LevelUpSuggestion.suggestedLevel(recentResults: recentResults, currentLevel: issue.masteryLevel)
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
        if LevelUpSuggestion.consecutiveDoneCount(recentResults: recentResults) < LevelUpSuggestion.requiredStreak {
            return nil
        }
        return nextLevel
    }
}
