import XCTest
import Foundation
@testable import BadNote

/// 層の上下(§3.3 / §7.4 の 1 段上げる・1 段下げる)。
final class TierOrderTests: XCTestCase {

    func testFocusHasNoHigherTier() throws {
        XCTAssertNil(Tier.focus.higher)
    }

    func testNextMovesUpToFocus() throws {
        XCTAssertEqual(Tier.focus, Tier.next.higher)
    }

    func testSomedayMovesUpToNext() throws {
        XCTAssertEqual(Tier.next, Tier.someday.higher)
    }

    func testSomedayHasNoLowerTier() throws {
        XCTAssertNil(Tier.someday.lower)
    }

    func testFocusMovesDownToNext() throws {
        XCTAssertEqual(Tier.next, Tier.focus.lower)
    }

    func testNextMovesDownToSomeday() throws {
        XCTAssertEqual(Tier.someday, Tier.next.lower)
    }

    /// 未整理でも一覧に出せるよう、doneForm が無ければ原文を表示する。
    func testDisplayTitleFallsBackToCoachWords() throws {
        let issue = Issue(id: 1,
                          coachWords: "もっとラケット面、下向いてるよ",
                          createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                          updatedAt: Date(timeIntervalSince1970: 1_700_000_000))

        XCTAssertEqual("もっとラケット面、下向いてるよ", issue.displayTitle)
    }

    func testDisplayTitlePrefersDoneForm() throws {
        let issue = Issue(id: 1,
                          coachWords: "もっとラケット面、下向いてるよ",
                          doneForm: "レシーブでラケット面を立てて構えられている",
                          createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                          updatedAt: Date(timeIntervalSince1970: 1_700_000_000))

        XCTAssertEqual("レシーブでラケット面を立てて構えられている", issue.displayTitle)
    }
}
