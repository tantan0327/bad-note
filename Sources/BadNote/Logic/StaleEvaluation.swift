import Foundation

/// stale と判定した理由(§4.2)。raw value は `stale_flag.reason` に入る値。
public enum StaleReason: String, CaseIterable, Hashable {
    /// 登録から `stale_days` 以上、一度も重点に入っていない
    case neverFocused = "never_focused"
    /// 重点を外れてから `stale_practice_count` 回以上練習している
    case leftFocus = "left_focus"
}

/// stale 判定の閾値(§4.2)。
///
/// 初期値は `app_meta` に持たせて後から調整できるようにする。
/// 判定ロジック側に埋め込まず、呼び出し側が読み込んだ値を渡す。
public struct StaleThresholds: Hashable, Sendable {
    /// `stale_days`。何日放置で候補にするか。
    public var days: Int
    /// `stale_practice_count`。重点を外れて何回の練習で候補にするか。
    public var practiceCount: Int

    public init(days: Int = 21, practiceCount: Int = 6) {
        self.days = days
        self.practiceCount = practiceCount
    }

    /// §4.2 の初期値。`app_meta` が空のときはこれを使う。
    public static let standard = StaleThresholds()
}

/// stale(しばらく触れていない課題)の判定(§4.2)。
///
/// 純粋関数。課題 1 件分の情報と基準日から理由を決めるだけで、優先度は書き換えない
/// (§4.3 自動で優先度を書き換えない。候補として提示するだけ)。
///
/// 再浮上の目的は技術の劣化ではなく**意識からの消失**なので、判定は「触れていない」
/// ことだけを見る。手応えの良し悪しは条件に入れない(§4.1)。
public struct StaleEvaluation {
    private init() {
    }

    private static let secondsPerDay = 86_400.0

    /// stale なら理由を、そうでなければ nil を返す。
    ///
    /// 対象外(必ず nil):
    /// - `status == .archived` —— 定着した課題は掘り返さない
    /// - `tier == .focus` —— 今週やっているものを「触れていない」とは言わない(§4.2)
    ///
    /// 判定(§4.2):
    /// - **never_focused** —— 一度も重点に入らないまま `days` 日以上経過
    /// - **left_focus** —— 重点を外れてからの練習が `practiceCount` 回以上
    ///
    /// 2 つは重点の経験有無で排他なので同時には成立しない。
    ///
    /// - Parameter focusCount: 重点に入った回数(`focus_span` の件数)。0 なら未経験。
    /// - Parameter practiceCountSinceLeavingFocus: 最後に重点を外れて以降の練習件数。
    ///   重点未経験なら意味を持たない(0 を渡してよい)。
    public static func reason(status: IssueStatus,
                              tier: Tier,
                              createdAt: Date,
                              focusCount: Int,
                              practiceCountSinceLeavingFocus: Int,
                              asOf: Date,
                              thresholds: StaleThresholds = StaleThresholds.standard) -> StaleReason? {
        if status == IssueStatus.archived {
            return nil
        }
        if tier == Tier.focus {
            return nil
        }

        if focusCount <= 0 {
            let elapsedDays = asOf.timeIntervalSince(createdAt) / StaleEvaluation.secondsPerDay
            if elapsedDays >= Double(thresholds.days) {
                return StaleReason.neverFocused
            }
            // 重点未経験の課題に left_focus は成立しない
            return nil
        }

        if practiceCountSinceLeavingFocus >= thresholds.practiceCount {
            return StaleReason.leftFocus
        }
        return nil
    }
}
