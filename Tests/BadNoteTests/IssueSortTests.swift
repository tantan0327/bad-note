import XCTest
import Foundation
@testable import BadNote

/// 課題一覧を眺める順(§3.3)。
///
/// **表示の切り替えだけ。`sortOrder`(保存順)は書き換えない。**
/// ここが壊れると、並べ替えたつもりが手動の並びを壊すことになる。
final class IssueSortTests: XCTestCase {

    private let base = Date(timeIntervalSince1970: 1_750_000_000.0)

    private func issue(id: Int64,
                       sortOrder: Int = 0,
                       impact: Int? = nil,
                       cost: Int? = nil,
                       level: MasteryLevel = MasteryLevel.solo,
                       createdDaysAgo: Double = 0.0,
                       focusedDaysAgo: Double? = nil) -> Issue {
        // Kotlin は Double に Int リテラルを入れられない。小数で書く
        let day: Double = 60.0 * 60.0 * 24.0
        var focusedAt: Date? = nil
        if let focusedDaysAgo = focusedDaysAgo {
            focusedAt = Date(timeIntervalSince1970: base.timeIntervalSince1970 - focusedDaysAgo * day)
        }
        return Issue(id: id,
                     coachWords: "課題 \(id)",
                     masteryLevel: level,
                     sortOrder: sortOrder,
                     impact: impact,
                     cost: cost,
                     status: IssueStatus.active,
                     lastFocusedAt: focusedAt,
                     createdAt: Date(timeIntervalSince1970: base.timeIntervalSince1970 - createdDaysAgo * day),
                     updatedAt: base)
    }

    private func ids(_ issues: [Issue]) -> [Int64] {
        var result: [Int64] = []
        for issue in issues {
            result.append(issue.id)
        }
        return result
    }

    // MARK: - 手動

    /// `fetch` が `ORDER BY sort_order, id` で返しているので、手動では触らない。
    func testManualKeepsTheGivenOrder() {
        let given = [issue(id: 3, sortOrder: 0),
                     issue(id: 1, sortOrder: 5),
                     issue(id: 2, sortOrder: 1)]

        let sorted = IssueSort.sorted(given, by: IssueSortOrder.manual)

        XCTAssertEqual([Int64(3), Int64(1), Int64(2)], ids(sorted))
    }

    func testManualAllowsDragAndOthersDoNot() {
        XCTAssertTrue(IssueSortOrder.manual.allowsDrag)
        XCTAssertFalse(IssueSortOrder.idle.allowsDrag)
        XCTAssertFalse(IssueSortOrder.impact.allowsDrag)
        XCTAssertFalse(IssueSortOrder.mastery.allowsDrag)
    }

    // MARK: - 放置が長い順

    /// 最後に重点に入った日が古いものから。
    func testIdlePutsTheLongestUntouchedFirst() {
        let given = [issue(id: 1, focusedDaysAgo: 3.0),
                     issue(id: 2, focusedDaysAgo: 40.0),
                     issue(id: 3, focusedDaysAgo: 10.0)]

        let sorted = IssueSort.sorted(given, by: IssueSortOrder.idle)

        XCTAssertEqual([Int64(2), Int64(3), Int64(1)], ids(sorted))
    }

    /// **一度も重点にしていない課題は登録日で数える**(§4.1 の「入れたきり埋もれた」)。
    /// 90 日前に登録して一度も触っていない課題は、30 日前に重点を外れた課題より放置が長い。
    func testIdleFallsBackToCreatedAtWhenNeverFocused() {
        let neverFocused = issue(id: 1, createdDaysAgo: 90.0)
        let recentlyFocused = issue(id: 2, createdDaysAgo: 200.0, focusedDaysAgo: 30.0)

        let sorted = IssueSort.sorted([recentlyFocused, neverFocused], by: IssueSortOrder.idle)

        XCTAssertEqual([Int64(1), Int64(2)], ids(sorted))
    }

    /// **`updatedAt` を見ていない。** タグを足しただけの課題が「触れた」ことになると、
    /// 放置の長さを表さなくなる。
    func testIdleIgnoresUpdatedAt() {
        var touchedJustNow = issue(id: 1, createdDaysAgo: 90.0)
        touchedJustNow.updatedAt = base
        var old = issue(id: 2, createdDaysAgo: 10.0)
        old.updatedAt = Date(timeIntervalSince1970: base.timeIntervalSince1970 - 60.0 * 60.0 * 24.0 * 365.0)

        let sorted = IssueSort.sorted([old, touchedJustNow], by: IssueSortOrder.idle)

        XCTAssertEqual([Int64(1), Int64(2)], ids(sorted))
    }

    // MARK: - 影響度が大きい順

    func testImpactPutsTheLargestFirst() {
        let given = [issue(id: 1, impact: 1),
                     issue(id: 2, impact: 3),
                     issue(id: 3, impact: 2)]

        let sorted = IssueSort.sorted(given, by: IssueSortOrder.impact)

        XCTAssertEqual([Int64(2), Int64(3), Int64(1)], ids(sorted))
    }

    /// 入力は任意なので、未入力が普通(§3.4)。**未入力は最後。**
    func testImpactPutsUnansweredLast() {
        let given = [issue(id: 1),
                     issue(id: 2, impact: 1)]

        let sorted = IssueSort.sorted(given, by: IssueSortOrder.impact)

        XCTAssertEqual([Int64(2), Int64(1)], ids(sorted))
    }

    /// 同じ影響度ならコストが小さい順 —— §3.4 の「すぐ効く」(影響度 3 × コスト 1)が先頭に来る。
    func testImpactBreaksTiesByCheapestCost() {
        let given = [issue(id: 1, impact: 3, cost: 3),
                     issue(id: 2, impact: 3, cost: 1),
                     issue(id: 3, impact: 3)]

        let sorted = IssueSort.sorted(given, by: IssueSortOrder.impact)

        XCTAssertEqual([Int64(2), Int64(1), Int64(3)], ids(sorted))
    }

    // MARK: - 習熟度が高い順

    /// 「克服した」は Lv.4 でしか押せないので、**減らす手がかりが先頭に集まる**。
    func testMasteryPutsTheHighestFirst() {
        let given = [issue(id: 1, level: MasteryLevel.solo),
                     issue(id: 2, level: MasteryLevel.match),
                     issue(id: 3, level: MasteryLevel.drill)]

        let sorted = IssueSort.sorted(given, by: IssueSortOrder.mastery)

        XCTAssertEqual([Int64(2), Int64(3), Int64(1)], ids(sorted))
    }

    // MARK: - 同点の割り方

    /// **同点は手動の並び → id で割る。** 割らないと、影響度を入れていない課題どうしの
    /// 順番が読み込むたびに変わり、「さっきと場所が違う」が起きる。
    func testTiesFallBackToManualOrderThenID() {
        let given = [issue(id: 9, sortOrder: 2),
                     issue(id: 4, sortOrder: 1),
                     issue(id: 2, sortOrder: 1)]

        let sorted = IssueSort.sorted(given, by: IssueSortOrder.impact)

        XCTAssertEqual([Int64(2), Int64(4), Int64(9)], ids(sorted))
    }

    // MARK: - 保存順を書き換えない

    /// §3.3「表示切り替えのみで、保存順序を変更しない」。
    /// 並べ替えた結果の `sortOrder` が元のままであることを直接見る。
    func testSortingDoesNotRewriteStoredOrder() {
        let given = [issue(id: 1, sortOrder: 0, impact: 1),
                     issue(id: 2, sortOrder: 1, impact: 3)]

        let sorted = IssueSort.sorted(given, by: IssueSortOrder.impact)

        XCTAssertEqual([Int64(2), Int64(1)], ids(sorted))
        // 先頭に来た課題の保存順は 1 のまま(0 に振り直されていない)
        XCTAssertEqual(1, sorted[0].sortOrder)
        XCTAssertEqual(0, sorted[1].sortOrder)
    }

    /// 渡した配列そのものを並べ替えない(呼び出し側の `fetch` 結果を壊さない)。
    func testSortingLeavesTheInputArrayAlone() {
        let given = [issue(id: 1, impact: 1),
                     issue(id: 2, impact: 3)]

        _ = IssueSort.sorted(given, by: IssueSortOrder.impact)

        XCTAssertEqual([Int64(1), Int64(2)], ids(given))
    }
}
