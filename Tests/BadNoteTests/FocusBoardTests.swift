import XCTest
import Foundation
@testable import BadNote

/// 重点 3 枠と層の並びの管理(§3.3 / §7.4)。
///
/// 純粋関数。課題の集合を受け取り、**更新が必要な課題だけ**を返す。
/// 保存するのは呼び出し側(`IssueRepository.update`)。
final class FocusBoardTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func issue(_ id: Int64, _ tier: Tier, _ sortOrder: Int) -> Issue {
        return Issue(id: id,
                     coachWords: "課題\(id)",
                     tier: tier,
                     sortOrder: sortOrder,
                     createdAt: t0,
                     updatedAt: t0)
    }

    private func find(_ id: Int64, in issues: [Issue]) throws -> Issue {
        var found: Issue? = nil
        for issue in issues {
            if issue.id == id {
                found = issue
            }
        }
        return try XCTUnwrap(found, "id \(id) が結果に含まれていること")
    }

    private func contains(_ id: Int64, in issues: [Issue]) -> Bool {
        for issue in issues {
            if issue.id == id {
                return true
            }
        }
        return false
    }

    // MARK: - 上限

    func testFocusCapacityIsThree() throws {
        XCTAssertEqual(3, FocusBoard.focusCapacity)
    }

    // MARK: - 空きがあるとき

    func testMoveIntoFocusWithRoomApplies() throws {
        let issues = [issue(1, .focus, 0), issue(2, .next, 0)]

        let result = FocusBoard.move(issue(2, .next, 0), to: .focus, at: 1, in: issues)

        XCTAssertNotNil(result.updatedIssues, "空きがあればそのまま適用できる")
    }

    func testMoveIntoFocusWithRoomSetsTier() throws {
        let issues = [issue(1, .focus, 0), issue(2, .next, 0)]

        let result = FocusBoard.move(issue(2, .next, 0), to: .focus, at: 1, in: issues)

        let updated = try XCTUnwrap(result.updatedIssues)
        let moved = try find(2, in: updated)
        XCTAssertEqual(Tier.focus, moved.tier)
    }

    func testMoveIntoFocusPlacesIssueAtGivenIndex() throws {
        let issues = [issue(1, .focus, 0), issue(2, .focus, 1), issue(3, .next, 0)]

        let result = FocusBoard.move(issue(3, .next, 0), to: .focus, at: 0, in: issues)

        let updated = try XCTUnwrap(result.updatedIssues)
        XCTAssertEqual(0, try find(3, in: updated).sortOrder)
        XCTAssertEqual(1, try find(1, in: updated).sortOrder)
    }

    /// 抜けた層の並びは詰める。穴を残さない。
    func testMoveCompactsSourceTier() throws {
        let issues = [issue(1, .next, 0), issue(2, .next, 1), issue(3, .next, 2)]

        let result = FocusBoard.move(issue(1, .next, 0), to: .focus, at: 0, in: issues)

        let updated = try XCTUnwrap(result.updatedIssues)
        XCTAssertEqual(0, try find(2, in: updated).sortOrder)
        XCTAssertEqual(1, try find(3, in: updated).sortOrder)
    }

    // MARK: - 3 枠が埋まっているとき

    /// §7.4 4 つ目を上げようとしたら「どれと入れ替えますか?」と現在の 3 つを提示。
    func testMoveIntoFullFocusReturnsSwapCandidates() throws {
        let issues = [issue(1, .focus, 0), issue(2, .focus, 1), issue(3, .focus, 2), issue(4, .next, 0)]

        let result = FocusBoard.move(issue(4, .next, 0), to: .focus, at: 0, in: issues)

        let candidates = try XCTUnwrap(result.swapCandidates)
        XCTAssertEqual(3, candidates.count)
    }

    func testSwapCandidatesAreCurrentFocusInSortOrder() throws {
        let issues = [issue(3, .focus, 2), issue(1, .focus, 0), issue(2, .focus, 1), issue(4, .someday, 0)]

        let result = FocusBoard.move(issue(4, .someday, 0), to: .focus, at: 0, in: issues)

        let candidates = try XCTUnwrap(result.swapCandidates)
        XCTAssertEqual([Int64(1), Int64(2), Int64(3)], candidates.map { $0.id })
    }

    /// 拒否だけで終わらせない。候補を返すが、この時点では何も変更しない。
    func testMoveIntoFullFocusAppliesNothing() throws {
        let issues = [issue(1, .focus, 0), issue(2, .focus, 1), issue(3, .focus, 2), issue(4, .next, 0)]

        let result = FocusBoard.move(issue(4, .next, 0), to: .focus, at: 0, in: issues)

        XCTAssertNil(result.updatedIssues)
    }

    /// 既に重点にある課題の並び替えは 4 件目にならないので上限に掛からない。
    func testReorderWithinFullFocusIsAllowed() throws {
        let issues = [issue(1, .focus, 0), issue(2, .focus, 1), issue(3, .focus, 2)]

        let result = FocusBoard.move(issue(3, .focus, 2), to: .focus, at: 0, in: issues)

        let updated = try XCTUnwrap(result.updatedIssues)
        XCTAssertEqual(0, try find(3, in: updated).sortOrder)
    }

    // MARK: - 入れ替えの確定

    func testSwapDemotesChosenIssueToNext() throws {
        let issues = [issue(1, .focus, 0), issue(2, .focus, 1), issue(3, .focus, 2), issue(4, .next, 0)]

        let updated = FocusBoard.swap(promoting: issue(4, .next, 0), demoting: issue(2, .focus, 1), in: issues)

        XCTAssertEqual(Tier.next, try find(2, in: updated).tier)
    }

    func testSwapPromotesIssueIntoFocus() throws {
        let issues = [issue(1, .focus, 0), issue(2, .focus, 1), issue(3, .focus, 2), issue(4, .next, 0)]

        let updated = FocusBoard.swap(promoting: issue(4, .next, 0), demoting: issue(2, .focus, 1), in: issues)

        XCTAssertEqual(Tier.focus, try find(4, in: updated).tier)
    }

    /// 降りた課題のいた枠に入る。残りの 2 件は動かさない。
    func testSwapPutsPromotedIssueInVacatedSlot() throws {
        let issues = [issue(1, .focus, 0), issue(2, .focus, 1), issue(3, .focus, 2), issue(4, .next, 0)]

        let updated = FocusBoard.swap(promoting: issue(4, .next, 0), demoting: issue(2, .focus, 1), in: issues)

        XCTAssertEqual(1, try find(4, in: updated).sortOrder)
        XCTAssertFalse(contains(1, in: updated), "動いていない課題は更新対象に含めない")
        XCTAssertFalse(contains(3, in: updated), "動いていない課題は更新対象に含めない")
    }

    /// someday からの昇格でも成立する。
    func testSwapWorksFromSomeday() throws {
        let issues = [issue(1, .focus, 0), issue(2, .focus, 1), issue(3, .focus, 2), issue(4, .someday, 0)]

        let updated = FocusBoard.swap(promoting: issue(4, .someday, 0), demoting: issue(2, .focus, 1), in: issues)

        XCTAssertEqual(Tier.focus, try find(4, in: updated).tier)
    }

    /// 降りた課題は next の末尾に付く。
    func testSwapAppendsDemotedIssueToEndOfNext() throws {
        let issues = [issue(1, .focus, 0), issue(2, .focus, 1), issue(3, .focus, 2),
                      issue(4, .next, 0), issue(5, .next, 1)]

        let updated = FocusBoard.swap(promoting: issue(4, .next, 0), demoting: issue(2, .focus, 1), in: issues)

        XCTAssertEqual(1, try find(2, in: updated).sortOrder, "next は 5 が 0、降りた 2 が 1")
    }

    /// 重点に無い課題を降ろそうとしたら何もしない(4 件になるのを防ぐ)。
    func testSwapIgnoresDemotingIssueOutsideFocus() throws {
        let issues = [issue(1, .focus, 0), issue(2, .focus, 1), issue(3, .focus, 2),
                      issue(4, .next, 0), issue(5, .next, 1)]

        let updated = FocusBoard.swap(promoting: issue(4, .next, 0), demoting: issue(5, .next, 1), in: issues)

        XCTAssertEqual(0, updated.count)
    }

    func testSwapIgnoresPromotingIssueAlreadyInFocus() throws {
        let issues = [issue(1, .focus, 0), issue(2, .focus, 1), issue(3, .focus, 2)]

        let updated = FocusBoard.swap(promoting: issue(1, .focus, 0), demoting: issue(2, .focus, 1), in: issues)

        XCTAssertEqual(0, updated.count)
    }

    // MARK: - 層内の並び替え

    func testReorderAssignsSequentialSortOrder() throws {
        let issues = [issue(1, .next, 0), issue(2, .next, 5), issue(3, .next, 9)]

        let result = FocusBoard.move(issue(3, .next, 9), to: .next, at: 0, in: issues)

        let updated = try XCTUnwrap(result.updatedIssues)
        XCTAssertEqual(0, try find(3, in: updated).sortOrder)
        XCTAssertEqual(1, try find(1, in: updated).sortOrder)
        XCTAssertEqual(2, try find(2, in: updated).sortOrder)
    }

    func testReorderToEndMakesItLast() throws {
        let issues = [issue(1, .next, 0), issue(2, .next, 1), issue(3, .next, 2)]

        let result = FocusBoard.move(issue(1, .next, 0), to: .next, at: 2, in: issues)

        let updated = try XCTUnwrap(result.updatedIssues)
        XCTAssertEqual(2, try find(1, in: updated).sortOrder)
    }

    // MARK: - 変更されたものだけ返す

    /// 動いていない課題まで返すと、保存時に updated_at が更新されて
    /// §4.2 の「放置期間」判定がリセットされてしまう。
    func testReturnsOnlyChangedIssues() throws {
        let issues = [issue(1, .focus, 0), issue(2, .next, 0), issue(3, .someday, 0)]

        let result = FocusBoard.move(issue(2, .next, 0), to: .focus, at: 1, in: issues)

        let updated = try XCTUnwrap(result.updatedIssues)
        XCTAssertEqual([Int64(2)], updated.map { $0.id }, "動いたのは 2 だけ")
    }

    func testMoveToSamePositionReturnsNoChanges() throws {
        let issues = [issue(1, .next, 0), issue(2, .next, 1)]

        let result = FocusBoard.move(issue(1, .next, 0), to: .next, at: 0, in: issues)

        let updated = try XCTUnwrap(result.updatedIssues)
        XCTAssertEqual(0, updated.count)
    }

    // MARK: - 位置の丸め

    func testIndexBeyondEndAppends() throws {
        let issues = [issue(1, .next, 0), issue(2, .next, 1), issue(3, .someday, 0)]

        let result = FocusBoard.move(issue(3, .someday, 0), to: .next, at: 99, in: issues)

        let updated = try XCTUnwrap(result.updatedIssues)
        XCTAssertEqual(2, try find(3, in: updated).sortOrder)
    }

    func testNegativeIndexInsertsAtTop() throws {
        let issues = [issue(1, .next, 0), issue(2, .next, 1), issue(3, .someday, 0)]

        let result = FocusBoard.move(issue(3, .someday, 0), to: .next, at: -5, in: issues)

        let updated = try XCTUnwrap(result.updatedIssues)
        XCTAssertEqual(0, try find(3, in: updated).sortOrder)
    }

    // MARK: - 降格

    func testMoveOutOfFocusFreesSlot() throws {
        let issues = [issue(1, .focus, 0), issue(2, .focus, 1), issue(3, .focus, 2), issue(4, .next, 0)]

        let afterDemotion = FocusBoard.move(issue(3, .focus, 2), to: .someday, at: 0, in: issues)
        let updated = try XCTUnwrap(afterDemotion.updatedIssues)
        var board: [Issue] = [issue(1, .focus, 0), issue(2, .focus, 1), issue(4, .next, 0)]
        board.append(try find(3, in: updated))

        let result = FocusBoard.move(issue(4, .next, 0), to: .focus, at: 2, in: board)

        XCTAssertNotNil(result.updatedIssues, "1 枠空いたので入れ替え無しで上げられる")
    }
}
