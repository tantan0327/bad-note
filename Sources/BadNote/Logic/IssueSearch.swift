import Foundation

/// 課題を言葉で探す(§7.4)。純粋関数。
///
/// 課題が増えると、絞り込み(種目 / 習熟度 / タグ)だけでは目当ての 1 件に辿り着けない。
/// **「あの時言われたやつ」を言葉から引く**ための入口。
///
/// 探すのは課題が持っている**言葉だけ** —— できている状態 / もとの言葉 / コーチ名。
/// 日付や数字は検索しない(覚えているのは言葉のほう)。
public enum IssueSearch {

    /// 検索語で絞る。**空(と空白だけ)なら何もしない。**
    ///
    /// 並び順は渡された配列のまま変えない。呼び出し側が層の順と
    /// `IssueSort` の並びを決めているので、ここで混ぜ返さない。
    public static func filtered(_ issues: [Issue], query: String) -> [Issue] {
        let needle = IssueSearch.normalized(query)
        if needle.isEmpty {
            return issues
        }
        var result: [Issue] = []
        for issue in issues {
            if IssueSearch.matches(issue, needle: needle) {
                result.append(issue)
            }
        }
        return result
    }

    /// 検索語が実際に効いているか。空白だけの入力は「探していない」とみなす。
    public static func isActive(_ query: String) -> Bool {
        return !IssueSearch.normalized(query).isEmpty
    }

    /// 前後の空白を落として小文字に揃える。
    ///
    /// **日本語には小文字化が効かない**ので、効くのは英字を混ぜたときだけ。
    /// ひらがなとカタカナの読み替えまではしない —— 入れるなら、
    /// 期待どおりに動くかを実機で確かめてからにする。
    static func normalized(_ text: String) -> String {
        return text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).lowercased()
    }

    /// 1 件が検索語を含むか。`needle` は `normalized` 済みを渡す。
    static func matches(_ issue: Issue, needle: String) -> Bool {
        if needle.isEmpty {
            return true
        }
        // 主表示(言い換えがあればそちら、無ければ原文)
        if IssueSearch.normalized(issue.displayTitle).contains(needle) {
            return true
        }
        // 言い換えを持っている課題は、原文のほうも探せないと
        // 「言われたとおりの言葉」で引けなくなる
        if IssueSearch.normalized(issue.coachWords).contains(needle) {
            return true
        }
        if let coachName = issue.coachName {
            if IssueSearch.normalized(coachName).contains(needle) {
                return true
            }
        }
        return false
    }
}
