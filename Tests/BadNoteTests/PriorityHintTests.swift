import XCTest
@testable import BadNote

/// 影響度 × コストから出す手がかり(§3.4)。
///
/// アプリは解釈や警告を出さない —— **並べ替えも自動選択もせず、目印を 1 つ添えるだけ。**
final class PriorityHintTests: XCTestCase {

    /// 影響度が大きく、すぐ直る = 重点に入れるべき候補(§3.4)。
    func testQuickWin() {
        XCTAssertEqual(PriorityHint.forIssue(impact: 3, cost: 1), PriorityHint.quickWin)
    }

    /// 影響度が大きいが、シーズン単位でかかる(§3.4)。
    func testSeasonLong() {
        XCTAssertEqual(PriorityHint.forIssue(impact: 3, cost: 3), PriorityHint.seasonLong)
    }

    /// 影響度が大きくても、コストが中くらいなら目印を出さない。
    /// **目印だらけにすると目印の意味が無くなる。**
    func testNoHintForMiddleCost() {
        XCTAssertNil(PriorityHint.forIssue(impact: 3, cost: 2))
    }

    /// 影響度が大きくなければ、コストが何であっても出さない。
    func testNoHintWhenImpactIsNotLarge() {
        XCTAssertNil(PriorityHint.forIssue(impact: 1, cost: 1))
        XCTAssertNil(PriorityHint.forIssue(impact: 2, cost: 1))
        XCTAssertNil(PriorityHint.forIssue(impact: 2, cost: 3))
    }

    /// 未入力(どちらか欠けている)なら出さない。入力は任意なので欠けているのが普通。
    func testNoHintWhenUnset() {
        XCTAssertNil(PriorityHint.forIssue(impact: nil, cost: nil))
        XCTAssertNil(PriorityHint.forIssue(impact: 3, cost: nil))
        XCTAssertNil(PriorityHint.forIssue(impact: nil, cost: 1))
    }

    /// 表示は言葉にする(§3.4 数字は画面に出さない)。
    func testDisplayNames() {
        XCTAssertEqual(PriorityHint.quickWin.displayName, "すぐ効く")
        XCTAssertEqual(PriorityHint.seasonLong.displayName, "シーズン単位")
    }
}
