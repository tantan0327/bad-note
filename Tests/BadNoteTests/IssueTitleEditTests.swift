import XCTest
import Foundation
@testable import BadNote

/// 画面に出る 1 行を直したとき、どちらの列に書くか(2026-10-12)。
///
/// **書き留めた言葉は残す。直した文は言い換えに入る。**
/// ここが壊れると、言われたとおりの言葉が静かに上書きされる。
final class IssueTitleEditTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000.0)

    private func issue(coachWords: String, doneForm: String? = nil) -> Issue {
        return Issue(id: 1,
                     coachWords: coachWords,
                     doneForm: doneForm,
                     masteryLevel: MasteryLevel.solo,
                     status: IssueStatus.active,
                     createdAt: t0,
                     updatedAt: t0)
    }

    // MARK: - 画面に出す 1 行

    func testTitleIsTheOriginalWhenThereIsNoRephrase() {
        XCTAssertEqual("面が寝ている", IssueTitleEdit.title(of: issue(coachWords: "面が寝ている")))
    }

    func testTitlePrefersTheRephrase() {
        let given = issue(coachWords: "面が寝ている", doneForm: "ラケット面を立てて構えられている")

        XCTAssertEqual("ラケット面を立てて構えられている", IssueTitleEdit.title(of: given))
    }

    // MARK: - 直したとき

    /// **いちばん大事な約束。** 直しても言われた言葉は残る。
    func testEditingNeverTouchesTheOriginalWords() {
        let given = issue(coachWords: "面が寝ている")

        let edited = IssueTitleEdit.applied(to: given, title: "ラケット面を立てて構えられている", originalTitle: IssueTitleEdit.title(of: given))

        XCTAssertEqual("面が寝ている", edited.coachWords)
        XCTAssertEqual("ラケット面を立てて構えられている", edited.doneForm)
    }

    /// 言い換えを持っている課題を直すと、言い換えのほうが変わる。
    func testEditingReplacesTheExistingRephrase() {
        let given = issue(coachWords: "面が寝ている", doneForm: "面を立てられている")

        let edited = IssueTitleEdit.applied(to: given, title: "ラケット面を立てて構えられている", originalTitle: IssueTitleEdit.title(of: given))

        XCTAssertEqual("面が寝ている", edited.coachWords)
        XCTAssertEqual("ラケット面を立てて構えられている", edited.doneForm)
    }

    /// **元の文に戻したら言い換えは持たせない。**
    /// 同じ文を 2 つ持つと、課題詳細が同じ行を 2 度出す(`hasDoneForm` の判定)。
    func testEditingBackToTheOriginalDropsTheRephrase() {
        let given = issue(coachWords: "面が寝ている", doneForm: "面を立てられている")

        let edited = IssueTitleEdit.applied(to: given, title: "面が寝ている", originalTitle: IssueTitleEdit.title(of: given))

        XCTAssertEqual("面が寝ている", edited.coachWords)
        XCTAssertNil(edited.doneForm)
    }

    /// 前後の空白は無視する。見た目が同じなら同じ扱い。
    func testWhitespaceAroundTheTitleIsIgnored() {
        let given = issue(coachWords: "面が寝ている")

        let edited = IssueTitleEdit.applied(to: given, title: "  面が寝ている  ", originalTitle: IssueTitleEdit.title(of: given))

        XCTAssertNil(edited.doneForm)
    }

    func testTrimsTheSavedRephrase() {
        let given = issue(coachWords: "面が寝ている")

        let edited = IssueTitleEdit.applied(to: given, title: "  面を立てられている  ", originalTitle: IssueTitleEdit.title(of: given))

        XCTAssertEqual("面を立てられている", edited.doneForm)
    }

    /// 空にしても無題にならない。書き留めた言葉に戻るだけ。
    func testClearingTheTitleFallsBackToTheOriginal() {
        let given = issue(coachWords: "面が寝ている", doneForm: "面を立てられている")

        let edited = IssueTitleEdit.applied(to: given, title: "   ", originalTitle: IssueTitleEdit.title(of: given))

        XCTAssertEqual("面が寝ている", edited.coachWords)
        XCTAssertNil(edited.doneForm)
        XCTAssertEqual("面が寝ている", edited.displayTitle)
    }

    // MARK: - 表示との整合

    /// 直した結果が、そのまま一覧に出る 1 行になる。
    func testTheEditedTitleIsWhatTheListShows() {
        let given = issue(coachWords: "面が寝ている")

        let edited = IssueTitleEdit.applied(to: given, title: "ラケット面を立てて構えられている", originalTitle: IssueTitleEdit.title(of: given))

        XCTAssertEqual("ラケット面を立てて構えられている", edited.displayTitle)
        XCTAssertTrue(edited.hasDoneForm)
    }

    /// 言い換えを持たない課題は、詳細で原文を引用しない(同じ行が 2 度出ない)。
    func testIssueWithoutRephraseDoesNotQuoteItself() {
        let given = issue(coachWords: "面が寝ている")

        let edited = IssueTitleEdit.applied(to: given, title: "面が寝ている", originalTitle: IssueTitleEdit.title(of: given))

        XCTAssertFalse(edited.hasDoneForm)
    }

    // MARK: - 誤字修正(2026-10-18 に踏んだバグ)

    /// **もとの言葉の誤字だけ直したとき、1 行は巻き添えにしない。**
    ///
    /// 以前は新しい `coachWords` と比べていたため、**直す前の文(誤字)が
    /// 言い換えに入り**、一覧の行は誤字のまま固定されていた。
    /// 誤字修正はこの欄の唯一の用途なので、使えば必ず踏む。
    func testFixingATypoInTheOriginalDoesNotCreateARephrase() {
        // 「ハイクリア」を「ハイクリヤ」と書き間違えた課題。言い換えは持っていない
        let stored = issue(coachWords: "ハイクリヤが浅い")
        let titleOnScreen = IssueTitleEdit.title(of: stored)

        // 折りたたみを開いて、もとの言葉だけ直す(1 行は触らない)
        var fixed = stored
        fixed.coachWords = "ハイクリアが浅い"

        let edited = IssueTitleEdit.applied(to: fixed, title: titleOnScreen, originalTitle: titleOnScreen)

        XCTAssertEqual("ハイクリアが浅い", edited.coachWords)
        XCTAssertNil(edited.doneForm)
        // **一覧の行も直った文になる**(誤字のまま固定されない)
        XCTAssertEqual("ハイクリアが浅い", edited.displayTitle)
    }

    /// 言い換えを持っている課題でも、もとの言葉だけ直したなら言い換えは変わらない。
    func testFixingTheOriginalKeepsAnExistingRephrase() {
        let stored = issue(coachWords: "面が寝てる", doneForm: "ラケット面を立てて構えられている")
        let titleOnScreen = IssueTitleEdit.title(of: stored)

        var fixed = stored
        fixed.coachWords = "面が寝ている"

        let edited = IssueTitleEdit.applied(to: fixed, title: titleOnScreen, originalTitle: titleOnScreen)

        XCTAssertEqual("面が寝ている", edited.coachWords)
        XCTAssertEqual("ラケット面を立てて構えられている", edited.doneForm)
    }

    /// 1 行ともとの言葉を同時に直した場合は、1 行のほうが言い換えになる。
    func testEditingBothKeepsTheTitleAsTheRephrase() {
        let stored = issue(coachWords: "面が寝てる")
        let titleOnScreen = IssueTitleEdit.title(of: stored)

        var fixed = stored
        fixed.coachWords = "面が寝ている"

        let edited = IssueTitleEdit.applied(to: fixed,
                                            title: "ラケット面を立てて構えられている",
                                            originalTitle: titleOnScreen)

        XCTAssertEqual("面が寝ている", edited.coachWords)
        XCTAssertEqual("ラケット面を立てて構えられている", edited.doneForm)
    }
}
