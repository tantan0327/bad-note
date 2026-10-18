import XCTest
import Foundation
@testable import BadNote

/// 3 層を 1 つの並びに畳んだときの、ドラッグ移動先の逆算(§7.4 長押しドラッグ)。
///
/// SwiftUI の `onMove` はひとつの `ForEach` の中でしか働かないので、
/// 3 層を見出し行込みの 1 本のリストにして、落とした位置から層と位置を求める。
final class TierLayoutTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func issue(_ id: Int64, _ tier: Tier) -> Issue {
        return Issue(id: id, coachWords: "課題\(id)", tier: tier, createdAt: t0, updatedAt: t0)
    }

    /// 0 見出し(重点)/ 1 A / 2 B / **3 空き枠** / 4 見出し(次)/ 5 C / 6 見出し(いつか)/ 7 D
    ///
    /// 重点は 2 件なので**空き枠が 1 行**入る(1.10)。
    private func sampleRows() -> [TierRow] {
        return TierLayout.rows(focus: [issue(1, .focus), issue(2, .focus)],
                               next: [issue(3, .next)],
                               someday: [issue(4, .someday)])
    }

    // MARK: - 並びの組み立て

    func testRowsIncludeHeadersForEveryTier() throws {
        let rows = sampleRows()

        XCTAssertEqual(8, rows.count, "重点の空き枠 1 行を含む")
        XCTAssertTrue(rows[0].isHeader)
        XCTAssertTrue(rows[4].isHeader)
        XCTAssertTrue(rows[6].isHeader)
    }

    /// **空の層には落下先の行を置く。**
    /// 見出しは動かせない(`moveDisabled`)ので、見出しだけだとその層に落とせない。
    func testEmptyTierGetsAPlaceholderRow() throws {
        let rows = TierLayout.rows(focus: [], next: [], someday: [])

        XCTAssertEqual(6, rows.count, "層ごとに 見出し + 落下先 の 2 行")
        XCTAssertTrue(rows[0].isHeader)
        XCTAssertTrue(rows[1].isPlaceholder)
        XCTAssertEqual(Tier.focus, rows[1].tier)
    }

    /// 課題がある層には落下先の行を作らない。
    func testFilledTierHasNoPlaceholder() throws {
        let rows = sampleRows()

        for row in rows {
            XCTAssertFalse(row.isPlaceholder)
        }
    }

    /// 空の層に落とせること —— これが直したかった不具合。
    func testDropIntoEmptyTier() throws {
        // 重点 1 件 / 次にやる 0 件 / いつか 1 件
        let rows = TierLayout.rows(focus: [issue(1, .focus)], next: [], someday: [issue(2, .someday)])
        // 0 見出し(重点) / 1 課題1 / 2-3 空き枠 / 4 見出し(次) / 5 落下先 /
        // 6 見出し(いつか) / 7 課題2
        let target = try XCTUnwrap(TierLayout.target(movingFrom: 7, toOffset: 5, rows: rows))

        XCTAssertEqual(Tier.next, target.tier)
        XCTAssertEqual(0, target.index)
    }

    /// 落下先の行の後ろに落としても、その層の先頭に入る(空なので位置は 1 つしかない)。
    func testDropAfterPlaceholderStaysInThatTier() throws {
        let rows = TierLayout.rows(focus: [issue(1, .focus)], next: [], someday: [issue(2, .someday)])

        let target = try XCTUnwrap(TierLayout.target(movingFrom: 7, toOffset: 6, rows: rows))

        XCTAssertEqual(Tier.next, target.tier)
        XCTAssertEqual(0, target.index)
    }

    /// 落下先の行そのものは動かせない。
    func testMovingPlaceholderIsRejected() throws {
        // 0 見出し(重点) / 1 課題1 / 2-3 空き枠 / 4 見出し(次) / 5 落下先 /
        // 6 見出し(いつか) / 7 落下先
        let rows = TierLayout.rows(focus: [issue(1, .focus)], next: [], someday: [])

        XCTAssertNil(TierLayout.target(movingFrom: 5, toOffset: 1, rows: rows))
    }

    // MARK: - 移動先の逆算

    /// 重点の見出しの直後 = 重点の先頭。
    func testDropAfterFocusHeaderGoesToTopOfFocus() throws {
        let target = try XCTUnwrap(TierLayout.target(movingFrom: 7, toOffset: 1, rows: sampleRows()))

        XCTAssertEqual(Tier.focus, target.tier)
        XCTAssertEqual(0, target.index)
    }

    func testDropBetweenFocusIssues() throws {
        let target = try XCTUnwrap(TierLayout.target(movingFrom: 7, toOffset: 2, rows: sampleRows()))

        XCTAssertEqual(Tier.focus, target.tier)
        XCTAssertEqual(1, target.index)
    }

    /// 次にやるの見出しの直後 = 次にやるの先頭。
    func testDropAfterNextHeader() throws {
        let target = try XCTUnwrap(TierLayout.target(movingFrom: 7, toOffset: 5, rows: sampleRows()))

        XCTAssertEqual(Tier.next, target.tier)
        XCTAssertEqual(0, target.index)
    }

    func testDropAtEndGoesToLastTier() throws {
        let target = try XCTUnwrap(TierLayout.target(movingFrom: 1, toOffset: 8, rows: sampleRows()))

        XCTAssertEqual(Tier.someday, target.tier)
        XCTAssertEqual(1, target.index)
    }

    /// 一番上(最初の見出しより前)に落としたら最上位の層の先頭。
    func testDropAboveEverythingGoesToFirstTier() throws {
        let target = try XCTUnwrap(TierLayout.target(movingFrom: 7, toOffset: 0, rows: sampleRows()))

        XCTAssertEqual(Tier.focus, target.tier)
        XCTAssertEqual(0, target.index)
    }

    /// **動かしている行自身は数えない。**
    /// 重点の A(index 1)を B の下(toOffset 3)へ動かすと、重点の 1 番目になる。
    func testMovedRowIsNotCounted() throws {
        let target = try XCTUnwrap(TierLayout.target(movingFrom: 1, toOffset: 3, rows: sampleRows()))

        XCTAssertEqual(Tier.focus, target.tier)
        XCTAssertEqual(1, target.index)
    }

    /// 見出しそのものは動かせない。
    func testMovingHeaderIsRejected() throws {
        XCTAssertNil(TierLayout.target(movingFrom: 0, toOffset: 4, rows: sampleRows()))
    }

    /// 範囲外の位置は末尾に丸める。
    func testOutOfRangeOffsetIsClamped() throws {
        let target = try XCTUnwrap(TierLayout.target(movingFrom: 1, toOffset: 99, rows: sampleRows()))

        XCTAssertEqual(Tier.someday, target.tier)
    }

    // MARK: - 重点の空き枠(1.10。ホームと同じ「空き枠」を一覧にも出す)

    private func slotCount(_ rows: [TierRow]) -> Int {
        var count = 0
        for row in rows {
            if row.isSlot {
                count += 1
            }
        }
        return count
    }

    func testFocusShowsSlotsForEveryEmptySeat() throws {
        let rows = TierLayout.rows(focus: [issue(1, .focus)], next: [issue(2, .next)], someday: [])

        XCTAssertEqual(2, slotCount(rows), "3 枠のうち 1 つ埋まっているので空き枠は 2")
        XCTAssertEqual(Tier.focus, rows[2].tier)
        XCTAssertTrue(rows[2].isSlot)
    }

    /// 重点が空でも、他の層に課題があれば空き枠を 3 つ出す。
    func testEmptyFocusShowsThreeSlots() throws {
        let rows = TierLayout.rows(focus: [], next: [issue(1, .next)], someday: [])

        XCTAssertEqual(3, slotCount(rows))
    }

    func testFullFocusHasNoSlots() throws {
        let rows = TierLayout.rows(focus: [issue(1, .focus), issue(2, .focus), issue(3, .focus)],
                                   next: [],
                                   someday: [])

        XCTAssertEqual(0, slotCount(rows))
    }

    /// 3 枠を超えて入っている過渡状態でも空き枠は出さない(負にしない)。
    func testOverfilledFocusHasNoSlots() throws {
        let rows = TierLayout.rows(focus: [issue(1, .focus), issue(2, .focus),
                                           issue(3, .focus), issue(4, .focus)],
                                   next: [],
                                   someday: [])

        XCTAssertEqual(0, slotCount(rows))
    }

    /// **課題が 1 つも無い人には空き枠を見せない。**
    /// 空の盤面に空き枠だけ 3 つ並んでも意味が無い(初回の案内はホームが持つ)。
    func testAllEmptyBoardKeepsPlaceholderInsteadOfSlots() throws {
        let rows = TierLayout.rows(focus: [], next: [], someday: [])

        XCTAssertEqual(0, slotCount(rows))
        XCTAssertTrue(rows[1].isPlaceholder)
    }

    /// **空き枠を挟んでも移動先の位置がずれない。**
    /// `target` は課題の行しか数えないので、行が増えても計算は変わらない ——
    /// ドラッグが壊れていないことの要。
    func testSlotsDoNotShiftDropIndex() throws {
        // 0 見出し(重点) / 1 課題1 / 2-3 空き枠 / 4 見出し(次) / 5 課題2 / 6 見出し(いつか) / 7 課題3
        let rows = TierLayout.rows(focus: [issue(1, .focus)],
                                   next: [issue(2, .next)],
                                   someday: [issue(3, .someday)])

        // 空き枠 2 つを越えて「次にやる」の先頭へ落とす
        let target = try XCTUnwrap(TierLayout.target(movingFrom: 7, toOffset: 5, rows: rows))

        XCTAssertEqual(Tier.next, target.tier)
        XCTAssertEqual(0, target.index, "空き枠は位置に数えない")
    }

    /// 空き枠そのものは動かせない。
    func testMovingSlotIsRejected() throws {
        let rows = TierLayout.rows(focus: [issue(1, .focus)], next: [issue(2, .next)], someday: [])

        XCTAssertNil(TierLayout.target(movingFrom: 2, toOffset: 0, rows: rows))
    }

    // MARK: - 層を畳む(2026-10-12)

    /// 畳んだ層の課題は並びから消える。**件数は見出しが持つので、数は分かる。**
    func testCollapsedTierHidesItsIssues() {
        let rows = TierLayout.rows(focus: [issue(1, .focus)],
                                   next: [issue(2, .next)],
                                   someday: [issue(3, .someday),
                                             issue(4, .someday)],
                                   collapsed: [Tier.someday])

        var somedayIssueRows = 0
        for row in rows {
            if row.tier == Tier.someday && row.kind == TierRowKind.issue {
                somedayIssueRows += 1
            }
        }
        XCTAssertEqual(0, somedayIssueRows)
    }

    /// **畳んでも落下先は残す。** 無いとドラッグで運び込めなくなる
    /// (空の層で同じ失敗を踏んでいる)。
    func testCollapsedTierKeepsADropTarget() {
        let rows = TierLayout.rows(focus: [Issue](),
                                   next: [Issue](),
                                   someday: [issue(1, .someday),
                                             issue(2, .someday)],
                                   collapsed: [Tier.someday])

        var hasDropTarget = false
        for row in rows {
            if row.tier == Tier.someday && row.kind == TierRowKind.folded {
                hasDropTarget = true
            }
        }
        XCTAssertTrue(hasDropTarget)
    }

    /// **畳んだ層に「まだありません」を出さない**(2026-10-18 に踏んだ)。
    /// 「いつか 12件」の真下に並ぶと矛盾して見える。空の層とは別の行にする。
    func testCollapsedTierDoesNotUseTheEmptyRow() {
        let rows = TierLayout.rows(focus: [Issue](),
                                   next: [Issue](),
                                   someday: [issue(1, .someday)],
                                   collapsed: [Tier.someday])

        for row in rows {
            if row.tier == Tier.someday {
                XCTAssertNotEqual(TierRowKind.placeholder, row.kind)
            }
        }
    }

    /// 本当に空の層は、これまでどおり「まだありません」の行。
    func testEmptyTierStillUsesThePlaceholderRow() {
        let rows = TierLayout.rows(focus: [issue(1, .focus)],
                                   next: [Issue](),
                                   someday: [issue(2, .someday)])

        var hasPlaceholder = false
        for row in rows {
            if row.tier == Tier.next && row.kind == TierRowKind.placeholder {
                hasPlaceholder = true
            }
        }
        XCTAssertTrue(hasPlaceholder)
    }

    /// 畳んでいない層はこれまでどおり並ぶ。
    func testOtherTiersAreUnaffected() {
        let rows = TierLayout.rows(focus: [issue(1, .focus)],
                                   next: [issue(2, .next)],
                                   someday: [issue(3, .someday)],
                                   collapsed: [Tier.someday])

        var nextIssueRows = 0
        for row in rows {
            if row.tier == Tier.next && row.kind == TierRowKind.issue {
                nextIssueRows += 1
            }
        }
        XCTAssertEqual(1, nextIssueRows)
    }

    /// 既定で畳むのは「いつか」が溜まっているときだけ。
    func testInitialCollapseOnlyWhenSomedayIsLarge() {
        XCTAssertEqual([Tier](), TierLayout.initiallyCollapsed(somedayCount: 8))
        XCTAssertEqual([Tier.someday], TierLayout.initiallyCollapsed(somedayCount: 9))
    }

    /// 何も畳まないときは、これまでの並びと同じ。
    func testNoCollapseMatchesThePreviousLayout() {
        let focus = [issue(1, .focus)]
        let next = [issue(2, .next)]
        let someday = [issue(3, .someday)]

        let before = TierLayout.rows(focus: focus, next: next, someday: someday)
        let after = TierLayout.rows(focus: focus, next: next, someday: someday, collapsed: [Tier]())

        XCTAssertEqual(before.count, after.count)
    }
}
