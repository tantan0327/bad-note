import XCTest
@testable import BadNote

/// 節目(1.2 / モチベ)。到達済みだけを小さい順に返す純粋関数。
final class MilestoneTests: XCTestCase {

    func testNoneBeforeFirstMilestone() {
        // 空配列リテラル `[]` は Kotlin で Element の型推論ができない(開発メモ)
        XCTAssertEqual(Milestone.reachedHours(minutes: 0), [Int]())
        XCTAssertEqual(Milestone.reachedHours(minutes: 59), [Int]())
    }

    func testFirstAtOneHour() {
        XCTAssertEqual(Milestone.reachedHours(minutes: 60), [1])
    }

    func testExactBoundaryCounts() {
        XCTAssertEqual(Milestone.reachedHours(minutes: 5 * 60), [1, 5])
    }

    func testReturnsAllReachedInOrder() {
        XCTAssertEqual(Milestone.reachedHours(minutes: 10 * 60), [1, 5, 10])
        XCTAssertEqual(Milestone.reachedHours(minutes: 26 * 60), [1, 5, 10, 25])
    }

    /// 究極の目標は 1 万時間。到達済みの節目リストには含めない(別枠)。
    func testUltimateGoalIsTenThousandHours() {
        XCTAssertEqual(Milestone.ultimateHours, 10_000)
        XCTAssertFalse(Milestone.hasReachedUltimate(minutes: 9_999 * 60))
        XCTAssertTrue(Milestone.hasReachedUltimate(minutes: 10_000 * 60))
        // どれだけ積んでも reachedHours の最大は 1000
        XCTAssertEqual(Milestone.reachedHours(minutes: 10_000 * 60).last, 1000)
    }
}
