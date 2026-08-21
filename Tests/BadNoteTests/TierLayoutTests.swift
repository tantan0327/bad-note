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

    /// 0 見出し(重点)/ 1 A / 2 B / 3 見出し(次)/ 4 C / 5 見出し(いつか)/ 6 D
    private func sampleRows() -> [TierRow] {
        return TierLayout.rows(focus: [issue(1, .focus), issue(2, .focus)],
                               next: [issue(3, .next)],
                               someday: [issue(4, .someday)])
    }

    // MARK: - 並びの組み立て

    func testRowsIncludeHeadersForEveryTier() throws {
        let rows = sampleRows()

        XCTAssertEqual(7, rows.count)
        XCTAssertTrue(rows[0].isHeader)
        XCTAssertTrue(rows[3].isHeader)
        XCTAssertTrue(rows[5].isHeader)
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
        // 0 見出し(重点) / 1 課題1 / 2 見出し(次) / 3 落下先 / 4 見出し(いつか) / 5 課題2
        let target = try XCTUnwrap(TierLayout.target(movingFrom: 5, toOffset: 3, rows: rows))

        XCTAssertEqual(Tier.next, target.tier)
        XCTAssertEqual(0, target.index)
    }

    /// 落下先の行の後ろに落としても、その層の先頭に入る(空なので位置は 1 つしかない)。
    func testDropAfterPlaceholderStaysInThatTier() throws {
        let rows = TierLayout.rows(focus: [issue(1, .focus)], next: [], someday: [issue(2, .someday)])

        let target = try XCTUnwrap(TierLayout.target(movingFrom: 5, toOffset: 4, rows: rows))

        XCTAssertEqual(Tier.next, target.tier)
        XCTAssertEqual(0, target.index)
    }

    /// 落下先の行そのものは動かせない。
    func testMovingPlaceholderIsRejected() throws {
        let rows = TierLayout.rows(focus: [issue(1, .focus)], next: [], someday: [])

        XCTAssertNil(TierLayout.target(movingFrom: 3, toOffset: 1, rows: rows))
    }

    // MARK: - 移動先の逆算

    /// 重点の見出しの直後 = 重点の先頭。
    func testDropAfterFocusHeaderGoesToTopOfFocus() throws {
        let target = try XCTUnwrap(TierLayout.target(movingFrom: 6, toOffset: 1, rows: sampleRows()))

        XCTAssertEqual(Tier.focus, target.tier)
        XCTAssertEqual(0, target.index)
    }

    func testDropBetweenFocusIssues() throws {
        let target = try XCTUnwrap(TierLayout.target(movingFrom: 6, toOffset: 2, rows: sampleRows()))

        XCTAssertEqual(Tier.focus, target.tier)
        XCTAssertEqual(1, target.index)
    }

    /// 次にやるの見出しの直後 = 次にやるの先頭。
    func testDropAfterNextHeader() throws {
        let target = try XCTUnwrap(TierLayout.target(movingFrom: 6, toOffset: 4, rows: sampleRows()))

        XCTAssertEqual(Tier.next, target.tier)
        XCTAssertEqual(0, target.index)
    }

    func testDropAtEndGoesToLastTier() throws {
        let target = try XCTUnwrap(TierLayout.target(movingFrom: 1, toOffset: 7, rows: sampleRows()))

        XCTAssertEqual(Tier.someday, target.tier)
        XCTAssertEqual(1, target.index)
    }

    /// 一番上(最初の見出しより前)に落としたら最上位の層の先頭。
    func testDropAboveEverythingGoesToFirstTier() throws {
        let target = try XCTUnwrap(TierLayout.target(movingFrom: 6, toOffset: 0, rows: sampleRows()))

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
}
