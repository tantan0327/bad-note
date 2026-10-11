import Foundation

/// 棚卸しをいつ誘うか、何件見るか(2026-10-11)。
///
/// **月 1 回。** 課題は入口が自由で出口が実績ゲート(克服は Lv.4 のみ)なので、
/// 放っておくと「いつか」に溜まり続ける。定期的に**残すか見送るかを決める場**を作る。
///
/// 純粋関数。実際の読み書きは `IssueReviewModel` が行う。
public struct ReviewSchedule {
    private init() {
    }

    /// 次に誘うまでの間隔。**月 1 回**(stale の週 1 回より十分に長く取る)。
    public static let intervalDays = 30

    /// 誘う最小の件数。**これ未満なら誘わない。**
    ///
    /// 6 件の「いつか」に棚卸しは要らない。溜まって見通しが悪くなってから出す。
    /// 1 回で見る上限と同じ数にしてあるのは、**1 回で終わらせられる量から始める**ため。
    public static let minimumBacklog = 10

    /// 1 回で見る上限。**終わらない棚卸しは二度とやられない。**
    public static let sessionLimit = 10

    /// 今日、棚卸しに誘ってよいか。
    ///
    /// - 対象が `minimumBacklog` 未満なら誘わない(件数が先)
    /// - 一度もしていなければ誘う
    /// - 同じ日に 2 回は誘わない
    /// - 前回から `intervalDays` 日以上経っていれば誘う
    ///
    /// - Parameter backlogCount: 棚卸しの対象になる課題の数。
    public static func isDue(today: Date,
                             lastReviewedAt: Date?,
                             backlogCount: Int,
                             calendar: Calendar = Calendar.current) -> Bool {
        if backlogCount < ReviewSchedule.minimumBacklog {
            return false
        }
        guard let lastReviewedAt = lastReviewedAt else {
            return true
        }
        let startOfToday = calendar.startOfDay(for: today)
        // 起動のたびに誘わない
        if lastReviewedAt >= startOfToday {
            return false
        }
        let elapsedDays = today.timeIntervalSince(lastReviewedAt) / 86_400.0
        return elapsedDays >= Double(ReviewSchedule.intervalDays)
    }

    /// 1 回分の並び。**放置が長い順に、上限まで。**
    ///
    /// 並びは `IssueSort` の「放置が長い順」をそのまま使う ——
    /// いちばん忘れているものから聞くのが、見直す意味がいちばん大きい。
    ///
    /// **残した課題は翌月もまた出る。** 忘れているものを順に見せるのが目的なので、
    /// 一度残したからといって隠さない。
    public static func queue(from issues: [Issue]) -> [Issue] {
        let ordered = IssueSort.sorted(issues, by: IssueSortOrder.idle)
        var result: [Issue] = []
        for issue in ordered {
            if result.count >= ReviewSchedule.sessionLimit {
                break
            }
            result.append(issue)
        }
        return result
    }
}
