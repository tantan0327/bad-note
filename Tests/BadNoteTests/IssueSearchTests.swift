import XCTest
import Foundation
@testable import BadNote

/// 課題を言葉で探す(§7.4)。
///
/// 探せるのは課題が持っている言葉だけ —— できている状態 / もとの言葉 / コーチ名。
final class IssueSearchTests: XCTestCase {

    private func issue(id: Int64,
                       coachWords: String = "ハイクリアが浅い",
                       doneForm: String? = nil,
                       coachName: String? = nil) -> Issue {
        return Issue(id: id,
                     coachWords: coachWords,
                     doneForm: doneForm,
                     coachName: coachName,
                     masteryLevel: MasteryLevel.solo,
                     status: IssueStatus.active,
                     createdAt: Date(),
                     updatedAt: Date())
    }

    private func ids(_ issues: [Issue]) -> [Int64] {
        var result: [Int64] = []
        for issue in issues {
            result.append(issue.id)
        }
        return result
    }

    // MARK: - 探していないとき

    func testEmptyQueryKeepsEverything() {
        let given = [issue(id: 1), issue(id: 2)]

        XCTAssertEqual([Int64(1), Int64(2)], ids(IssueSearch.filtered(given, query: "")))
        XCTAssertFalse(IssueSearch.isActive(""))
    }

    /// 空白だけの入力は「探していない」。全部消したつもりで空白が残っていても、
    /// 0 件の画面にならない。
    func testBlankQueryKeepsEverything() {
        let given = [issue(id: 1), issue(id: 2)]

        XCTAssertEqual([Int64(1), Int64(2)], ids(IssueSearch.filtered(given, query: "   ")))
        XCTAssertFalse(IssueSearch.isActive("   "))
    }

    func testQueryWithCharactersIsActive() {
        XCTAssertTrue(IssueSearch.isActive("レシーブ"))
        XCTAssertTrue(IssueSearch.isActive("  レシーブ  "))
    }

    // MARK: - 何を探すか

    func testMatchesCoachWords() {
        let given = [issue(id: 1, coachWords: "レシーブで面が寝ている"),
                     issue(id: 2, coachWords: "ハイクリアが浅い")]

        XCTAssertEqual([Int64(1)], ids(IssueSearch.filtered(given, query: "レシーブ")))
    }

    func testMatchesDoneForm() {
        let given = [issue(id: 1, coachWords: "面が寝ている", doneForm: "ラケット面を立てて構えられている"),
                     issue(id: 2)]

        XCTAssertEqual([Int64(1)], ids(IssueSearch.filtered(given, query: "ラケット面")))
    }

    /// **言い換えを持っていても原文で引ける。**
    /// 覚えているのが「言われたとおりの言葉」のほうであることは多い。
    func testMatchesOriginalWordsEvenWhenRephrased() {
        let given = [issue(id: 1, coachWords: "面が寝ている", doneForm: "ラケット面を立てて構えられている")]

        XCTAssertEqual([Int64(1)], ids(IssueSearch.filtered(given, query: "寝ている")))
    }

    func testMatchesCoachName() {
        let given = [issue(id: 1, coachName: "田中コーチ"),
                     issue(id: 2)]

        XCTAssertEqual([Int64(1)], ids(IssueSearch.filtered(given, query: "田中")))
    }

    func testPartialWordMatches() {
        let given = [issue(id: 1, coachWords: "バックハンドのレシーブが浮く")]

        XCTAssertEqual([Int64(1)], ids(IssueSearch.filtered(given, query: "ハンド")))
    }

    func testNoMatchReturnsEmpty() {
        let given = [issue(id: 1, coachWords: "ハイクリアが浅い")]

        XCTAssertEqual([Int64](), ids(IssueSearch.filtered(given, query: "スマッシュ")))
    }

    // MARK: - 揃え方

    /// 英字を混ぜたときだけ効く。日本語には小文字化が効かない。
    func testIgnoresLetterCase() {
        let given = [issue(id: 1, coachWords: "Sサインの確認")]

        XCTAssertEqual([Int64(1)], ids(IssueSearch.filtered(given, query: "sサイン")))
        XCTAssertEqual([Int64(1)], ids(IssueSearch.filtered(given, query: "Sサイン")))
    }

    func testTrimsTheQuery() {
        let given = [issue(id: 1, coachWords: "レシーブで面が寝ている")]

        XCTAssertEqual([Int64(1)], ids(IssueSearch.filtered(given, query: "  レシーブ  ")))
    }

    // MARK: - 並びを混ぜない

    /// 呼び出し側が層の順と `IssueSort` の並びを決めているので、ここで並べ替えない。
    func testKeepsTheGivenOrder() {
        let given = [issue(id: 3, coachWords: "レシーブ A"),
                     issue(id: 1, coachWords: "レシーブ B"),
                     issue(id: 2, coachWords: "レシーブ C")]

        XCTAssertEqual([Int64(3), Int64(1), Int64(2)], ids(IssueSearch.filtered(given, query: "レシーブ")))
    }
}
