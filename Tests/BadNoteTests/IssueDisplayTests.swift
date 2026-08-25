import XCTest
import Foundation
@testable import BadNote

/// 課題の表示の決めごと(§3.1)。
final class IssueDisplayTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func issue(coachWords: String, doneForm: String? = nil) -> Issue {
        return Issue(id: 1,
                     coachWords: coachWords,
                     doneForm: doneForm,
                     createdAt: t0,
                     updatedAt: t0)
    }

    // MARK: - 主表示

    func testDisplayTitleUsesDoneFormWhenPresent() {
        let target = issue(coachWords: "面が下向き", doneForm: "面を立てて構えられている")
        XCTAssertEqual(target.displayTitle, "面を立てて構えられている")
    }

    func testDisplayTitleFallsBackToCoachWords() {
        XCTAssertEqual(issue(coachWords: "面が下向き").displayTitle, "面が下向き")
    }

    // MARK: - 言い換えを持っているか

    /// 言い換えがあるときだけ「もとの言葉」を引用する。**同じ文を 2 度出さないため**
    /// (2026-08-26。追加画面を 1 欄にしてから、大半の課題が言い換え無しになった)。
    func testHasDoneFormWhenRephrased() {
        XCTAssertTrue(issue(coachWords: "面が下向き", doneForm: "面を立てて構えられている").hasDoneForm)
    }

    func testHasDoneFormIsFalseWhenMissing() {
        XCTAssertFalse(issue(coachWords: "面が下向き").hasDoneForm)
        XCTAssertFalse(issue(coachWords: "面が下向き", doneForm: "").hasDoneForm)
    }

    /// 言い換えが原文とたまたま同じなら、引用しても情報が増えない。
    func testHasDoneFormIsFalseWhenSameAsCoachWords() {
        XCTAssertFalse(issue(coachWords: "面が下向き", doneForm: "面が下向き").hasDoneForm)
    }
}
