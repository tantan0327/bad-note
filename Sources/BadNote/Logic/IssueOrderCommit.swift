import Foundation

/// いま見えている並びを、保存順(`sortOrder`)に焼き付ける(2026-10-12)。
///
/// **「見る順」と「整理する順」が別々だと、優先順に整理できない。**
/// 並び替え(§3.3)は表示だけを入れ替えるので、影響度順で眺めている間は
/// 長押しドラッグが止まる。逆に手動の並びは実質「登録が古い順」で、
/// 優先順にはなっていない。どちらのモードでも優先順に整理できなかった。
///
/// そこで**本人が押したときだけ**、見えている順を保存順にする。
/// 焼き付けたあとは手動の並びに戻るので、そこから先はドラッグで微調整できる。
///
/// 仕様書 §3.3 の「自動ソートは表示切り替えのみ」は**自動には触らせない**という約束で、
/// ここは本人の操作なので矛盾しない(2026-10-12 に §3.3 へ追記した)。
public enum IssueOrderCommit {

    /// 渡された順に 0, 1, 2 … を振り直す。**変わったものだけ返す。**
    ///
    /// 全件返すと、動いていない課題の `updated_at` まで新しくなり、
    /// §4.2 の stale 判定(最終更新からの日数)が全部リセットされてしまう。
    public static func renumbered(_ issues: [Issue]) -> [Issue] {
        var changed: [Issue] = []
        var position = 0
        for issue in issues {
            if issue.sortOrder != position {
                var moved = issue
                moved.sortOrder = position
                changed.append(moved)
            }
            position += 1
        }
        return changed
    }
}
