import Foundation

/// 課題の「見えている 1 行」を直したとき、どちらの列に書くかの判断(2026-10-12)。
///
/// **画面に出す欄は 1 つだけにする。** 書き留めた言葉と言い換えを 2 欄並べると、
/// 追加画面では 1 欄だったものが編集画面で 2 欄になり、しかも片方が空になる。
/// 「さっき書いたのに、まだ書く欄がある」と見えるのが面倒さの正体だった。
///
/// 仕組みは変えない —— **書き留めた言葉(`coachWords`)は残したまま、
/// 直した文は言い換え(`doneForm`)に入れる。** 表示は `displayTitle` が
/// 言い換えを優先するので、見え方は 1 行のまま変わらない。
public enum IssueTitleEdit {

    /// 1 行を直した結果を返す。**`coachWords` は触らない。**
    ///
    /// - 直した文が書き留めた言葉と同じなら、言い換えは持たせない(nil)。
    ///   同じ文を 2 つ持つと、課題詳細が同じ行を 2 度出すことになる
    ///   (`Issue.hasDoneForm` が引用を出すかの判定に使っている)
    /// - 空白だけになったら、やはり言い換えは持たせない。
    ///   書き留めた言葉に戻るので、課題が無題になることはない
    public static func applied(to issue: Issue, title: String) -> Issue {
        var edited = issue
        edited.doneForm = IssueTitleEdit.doneForm(forTitle: title, coachWords: issue.coachWords)
        return edited
    }

    /// 画面に出す 1 行。`displayTitle` と同じだが、**編集の初期値**としての意味で分けてある。
    public static func title(of issue: Issue) -> String {
        return issue.displayTitle
    }

    static func doneForm(forTitle title: String, coachWords: String) -> String? {
        let trimmed = title.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if trimmed.isEmpty {
            return nil
        }
        if trimmed == coachWords.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) {
            return nil
        }
        return trimmed
    }
}
