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

    /// 空の層でも見出しは残す。移動先として選べる必要がある。
    func testEmptyTierKeepsItsHeader() throws {
        let rows = TierLayout.rows(focus: [], next: [], someday: [])

        XCTAssertEqual(3, rows.count)
        XCTAssertEqual(Tier.focus, rows[0].tier)
        XCTAssertEqual(Tier.next, rows[1].tier)
        XCTAssertEqual(Tier.someday, rows[2].tier)
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
