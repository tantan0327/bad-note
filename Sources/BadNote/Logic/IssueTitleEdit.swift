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
    /// - 直した文が**画面を開いた時点の 1 行**と同じなら、言い換えは変えない。
    ///   触っていない欄を書き換えないため(2026-10-18)
    /// - 直した文が書き留めた言葉と同じなら、言い換えは持たせない(nil)。
    ///   同じ文を 2 つ持つと、課題詳細が同じ行を 2 度出すことになる
    ///   (`Issue.hasDoneForm` が引用を出すかの判定に使っている)
    /// - 空白だけになったら、やはり言い換えは持たせない。
    ///   書き留めた言葉に戻るので、課題が無題になることはない
    ///
    /// - Parameter originalTitle: 画面を開いた時点の 1 行(`title(of:)` の値)。
    ///   **これが無いと誤字修正で壊れる** —— もとの言葉だけ直したとき、
    ///   新しい `coachWords` と比べてしまい、**直す前の文(誤字)が言い換えに入る**。
    ///   一覧の行は誤字のまま、詳細の引用だけ直った文になっていた。
    public static func applied(to issue: Issue, title: String, originalTitle: String) -> Issue {
        var edited = issue
        // 1 行を触っていないなら、言い換えには手を付けない
        if IssueTitleEdit.trimmed(title) == IssueTitleEdit.trimmed(originalTitle) {
            return edited
        }
        edited.doneForm = IssueTitleEdit.doneForm(forTitle: title, coachWords: issue.coachWords)
        return edited
    }

    /// 画面に出す 1 行。`displayTitle` と同じだが、**編集の初期値**としての意味で分けてある。
    public static func title(of issue: Issue) -> String {
        return issue.displayTitle
    }

    static func doneForm(forTitle title: String, coachWords: String) -> String? {
        let text = IssueTitleEdit.trimmed(title)
        if text.isEmpty {
            return nil
        }
        if text == IssueTitleEdit.trimmed(coachWords) {
            return nil
        }
        return text
    }

    static func trimmed(_ text: String) -> String {
        return text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
}
