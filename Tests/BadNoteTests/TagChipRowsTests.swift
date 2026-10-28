import XCTest
import Foundation
@testable import BadNote

/// タグの候補を何行に分けるか(2026-10-28)。
///
/// `Grid` が SkipUI 非対応なので折り返しを自前で組んでいる。
/// **端数と 0 件で間違えると画面が落ちる**ので、ここで固定する。
final class TagChipRowsTests: XCTestCase {

    private func tags(_ count: Int) -> [Tag] {
        var result: [Tag] = []
        for index in 0..<count {
            result.append(Tag(id: Int64(index + 1), name: "タグ\(index)"))
        }
        return result
    }

    private func names(_ tags: [Tag]) -> [String] {
        var result: [String] = []
        for tag in tags {
            result.append(tag.name)
        }
        return result
    }

    // MARK: - 行数

    func testNoTagsIsNoRows() {
        XCTAssertEqual(0, TagChipRows.rowCount(of: 0))
    }

    func testOneTagIsOneRow() {
        XCTAssertEqual(1, TagChipRows.rowCount(of: 1))
    }

    /// ちょうど 1 行分。
    func testFullRowIsOneRow() {
        XCTAssertEqual(1, TagChipRows.rowCount(of: 3))
    }

    /// **端数は切り上げる。** 切り捨てると最後のタグが画面から消える。
    func testRemainderRoundsUp() {
        XCTAssertEqual(2, TagChipRows.rowCount(of: 4))
    }

    /// 候補の上限(8)は 3 行に収まる。
    func testLimitFitsInThreeRows() {
        XCTAssertEqual(3, TagChipRows.rowCount(of: TagSuggestion.limit))
    }

    func testPerRowIsThree() {
        XCTAssertEqual(3, TagChipRows.perRow)
    }

    // MARK: - 行の中身

    func testFirstRowTakesTheFirstThree() {
        XCTAssertEqual(["タグ0", "タグ1", "タグ2"], names(TagChipRows.items(in: tags(7), row: 0)))
    }

    func testSecondRowContinues() {
        XCTAssertEqual(["タグ3", "タグ4", "タグ5"], names(TagChipRows.items(in: tags(7), row: 1)))
    }

    /// 最後の行は端数だけ。
    func testLastRowHoldsTheRemainder() {
        XCTAssertEqual(["タグ6"], names(TagChipRows.items(in: tags(7), row: 2)))
    }

    /// **全部の行を合わせると元の並びに戻る。** 落ちも重複もない
    func testEveryTagAppearsExactlyOnce() {
        let all = tags(8)
        var collected: [String] = []
        for row in 0..<TagChipRows.rowCount(of: all.count) {
            collected.append(contentsOf: names(TagChipRows.items(in: all, row: row)))
        }

        XCTAssertEqual(names(all), collected)
    }

    // MARK: - 範囲外

    /// **範囲外の行を渡されても落ちない。** 件数が減った瞬間に古い行番号で引かれる
    func testRowPastTheEndIsEmpty() {
        XCTAssertEqual([String](), names(TagChipRows.items(in: tags(2), row: 5)))
    }

    func testNegativeRowIsEmpty() {
        XCTAssertEqual([String](), names(TagChipRows.items(in: tags(2), row: -1)))
    }

    func testEmptyInputIsEmpty() {
        XCTAssertEqual([String](), names(TagChipRows.items(in: [], row: 0)))
    }
}
