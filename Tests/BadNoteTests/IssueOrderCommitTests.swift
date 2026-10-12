import XCTest
import Foundation
@testable import BadNote

/// 見えている並びを保存順に焼き付ける(§3.3、2026-10-12)。
///
/// **変わったものだけ返すのが仕様。** 全件返すと、動いていない課題の
/// `updated_at` まで新しくなり、§4.2 の stale 判定が全部リセットされる。
final class IssueOrderCommitTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000.0)

    private func issue(id: Int64, sortOrder: Int) -> Issue {
        return Issue(id: id,
                     coachWords: "課題 \(id)",
                     masteryLevel: MasteryLevel.solo,
                     tier: Tier.someday,
                     sortOrder: sortOrder,
                     status: IssueStatus.active,
                     createdAt: t0,
                     updatedAt: t0)
    }

    private func ids(_ issues: [Issue]) -> [Int64] {
        var result: [Int64] = []
        for issue in issues {
            result.append(issue.id)
        }
        return result
    }

    // MARK: - 焼き付け

    /// 渡された順に 0 から振り直す。
    /// **3 件とも位置が変わる値を選んである** —— 変わらない課題は返らないため。
    func testRenumbersInTheGivenOrder() {
        let given = [issue(id: 7, sortOrder: 5),
                     issue(id: 3, sortOrder: 9),
                     issue(id: 1, sortOrder: 7)]

        let changed = IssueOrderCommit.renumbered(given)

        XCTAssertEqual([Int64(7), Int64(3), Int64(1)], ids(changed))
        XCTAssertEqual(0, changed[0].sortOrder)
        XCTAssertEqual(1, changed[1].sortOrder)
        XCTAssertEqual(2, changed[2].sortOrder)
    }

    // MARK: - 触らないものは返さない

    /// すでにその位置にある課題は返さない。**書き込まないことが大事。**
    func testReturnsNothingWhenTheOrderIsAlreadyCorrect() {
        let given = [issue(id: 1, sortOrder: 0),
                     issue(id: 2, sortOrder: 1),
                     issue(id: 3, sortOrder: 2)]

        XCTAssertEqual([Int64](), ids(IssueOrderCommit.renumbered(given)))
    }

    /// 動いた 1 件だけ返す。残りの `updated_at` は触らせない。
    func testReturnsOnlyTheIssuesThatMoved() {
        let given = [issue(id: 1, sortOrder: 0),
                     issue(id: 2, sortOrder: 5),
                     issue(id: 3, sortOrder: 2)]

        let changed = IssueOrderCommit.renumbered(given)

        XCTAssertEqual([Int64(2)], ids(changed))
        XCTAssertEqual(1, changed[0].sortOrder)
    }

    func testEmptyTierCommitsNothing() {
        XCTAssertEqual([Int64](), ids(IssueOrderCommit.renumbered([Issue]())))
    }

    // MARK: - 中身は変えない

    /// 並び順以外はそのまま。層もレベルも触らない。
    func testOnlyTheSortOrderChanges() {
        var given = issue(id: 1, sortOrder: 9)
        given.tier = Tier.next
        given.masteryLevel = MasteryLevel.pattern

        let changed = IssueOrderCommit.renumbered([given])

        XCTAssertEqual(Tier.next, changed[0].tier)
        XCTAssertEqual(MasteryLevel.pattern, changed[0].masteryLevel)
        XCTAssertEqual(0, changed[0].sortOrder)
    }
}
