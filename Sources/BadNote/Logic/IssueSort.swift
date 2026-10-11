import Foundation

/// 課題一覧を眺める順(§3.3)。
///
/// **表示の切り替えだけ。保存順(`Issue.sortOrder`)は書き換えない。**
/// 仕様書 §3.3 が「自動ソート(影響度順、放置期間順、習熟度順)は**表示切り替えのみ**で、
/// 保存順序を変更しない」と定めている。
///
/// **アプリが選ぶわけではない**(CLAUDE.md「解釈や警告を出さない」)。
/// 層を勝手に動かしたり、おすすめを強調したりはしない。
/// どの順で眺めるかを本人が決めるだけで、課題の中身は何も変わらない。
public enum IssueSortOrder: String, CaseIterable, Hashable, Sendable {
    /// 既定。長押しドラッグで本人が並べた順(`sort_order`)。
    case manual
    /// 放置が長い順。課題が増えたときに**忘れているものから**見るための並び。
    case idle
    /// 影響度が大きい順。§3.4 の「すぐ効く」(影響度 3 × コスト 1)が先頭に来る。
    case impact
    /// 習熟度が高い順。**克服に近いものから見える** ——
    /// 「克服した」は Lv.4 でしか押せないので、減らす手がかりがここに集まる。
    case mastery

    /// 長押しドラッグを使ってよいのは手動のときだけ。
    ///
    /// 見えている順と保存順が違う状態で落とすと、**指を離した場所とは別の位置に入る**。
    /// 落ちる先が予想できない操作は、無効にするほうが親切。
    public var allowsDrag: Bool {
        return self == IssueSortOrder.manual
    }
}

/// 層ごとの並べ替え(§3.3)。純粋関数。**渡された配列は変えない。**
public enum IssueSort {

    /// 1 つの層を並べ替える。
    ///
    /// - Parameter order: `manual` なら何もしない。
    ///   `IssueRepository.fetch` が `ORDER BY sort_order, id` で返しているため。
    public static func sorted(_ issues: [Issue], by order: IssueSortOrder) -> [Issue] {
        if order == IssueSortOrder.manual {
            return issues
        }
        return issues.sorted(by: { first, second in
            return IssueSort.isBefore(first, second, order: order)
        })
    }

    /// 最後に触れた時刻。**重点に入った日が無ければ登録日。**
    ///
    /// 一度も重点にしていない古い課題がいちばん放置されている(§4.1 の
    /// 「インボックスに入れたきり埋もれた」がこれに当たる)。
    ///
    /// **`updatedAt` は使わない。** タグを 1 つ足しただけで「触れた」ことになってしまい、
    /// 放置の長さを表さなくなる。
    static func idleKey(_ issue: Issue) -> Double {
        let date = issue.lastFocusedAt ?? issue.createdAt
        return date.timeIntervalSince1970
    }

    private static func isBefore(_ first: Issue, _ second: Issue, order: IssueSortOrder) -> Bool {
        switch order {
        case .manual:
            return IssueSort.isBeforeByPosition(first, second)
        case .idle:
            let firstIdle = IssueSort.idleKey(first)
            let secondIdle = IssueSort.idleKey(second)
            if firstIdle != secondIdle {
                return firstIdle < secondIdle
            }
            return IssueSort.isBeforeByPosition(first, second)
        case .impact:
            // 未入力は 0 として最後へ。影響度もコストも任意なので、欠けているのが普通(§3.4)
            let firstImpact = first.impact ?? 0
            let secondImpact = second.impact ?? 0
            if firstImpact != secondImpact {
                return firstImpact > secondImpact
            }
            // 同じ影響度ならコストが小さい順。未入力は最大扱いで最後へ
            let firstCost = first.cost ?? 4
            let secondCost = second.cost ?? 4
            if firstCost != secondCost {
                return firstCost < secondCost
            }
            return IssueSort.isBeforeByPosition(first, second)
        case .mastery:
            let firstLevel = first.masteryLevel.rawValue
            let secondLevel = second.masteryLevel.rawValue
            if firstLevel != secondLevel {
                return firstLevel > secondLevel
            }
            return IssueSort.isBeforeByPosition(first, second)
        }
    }

    /// 同点の割り方。**必ず手動の並び → id で割る。**
    ///
    /// 割らないと、影響度を入れていない課題どうしの順番が読み込むたびに変わり、
    /// 「さっきと場所が違う」が起きる。
    private static func isBeforeByPosition(_ first: Issue, _ second: Issue) -> Bool {
        if first.sortOrder != second.sortOrder {
            return first.sortOrder < second.sortOrder
        }
        return first.id < second.id
    }
}
