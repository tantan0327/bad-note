import XCTest
@testable import BadNote

/// 節目(1.2 / モチベ)。到達・次・進捗・越えた瞬間を返す純粋関数。
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

    /// 階段は 1 万時間(1 万時間の法則)が最終段。1000 の次の欠落(2000・5000)も埋めた。
    func testLadderEndsAtTenThousandHours() {
        XCTAssertEqual(Milestone.hourThresholds.last, 10_000)
        XCTAssertEqual(Milestone.hourThresholds, [1, 5, 10, 25, 50, 100, 200, 500, 1000, 2000, 5000, 10_000])
    }

    // MARK: - 次の節目

    func testNextHoursBeforeFirst() {
        XCTAssertEqual(Milestone.nextHours(minutes: 0), 1)
        XCTAssertEqual(Milestone.nextHours(minutes: 59), 1)
    }

    /// 境界ちょうどは到達済み。次はその上の段。
    func testNextHoursAtBoundary() {
        XCTAssertEqual(Milestone.nextHours(minutes: 60), 5)
        XCTAssertEqual(Milestone.nextHours(minutes: 1000 * 60), 2000)
    }

    /// 全部登り切ったら次は無い。
    func testNextHoursNilAfterLastRung() {
        XCTAssertNil(Milestone.nextHours(minutes: 10_000 * 60))
    }

    // MARK: - 次の節目までの進み具合

    private func assertClose(_ actual: Double, _ expected: Double) {
        // accuracy 付きの XCTAssertEqual は Skip での挙動が未確認なので差分で見る
        XCTAssertTrue(abs(actual - expected) < 0.0001, "expected \(expected) but was \(actual)")
    }

    func testProgressStartsAtZero() {
        assertClose(Milestone.progressToNext(minutes: 0), 0.0)
    }

    /// 最初の節目(1 時間)へ 30 分 = 半分。
    func testProgressTowardFirstMilestone() {
        assertClose(Milestone.progressToNext(minutes: 30), 0.5)
    }

    /// 5 時間と 10 時間の中間(7.5 時間 = 450 分)= 半分。
    /// 区間の起点は直前の節目(累計 0 からではない)。
    func testProgressMeasuresFromPreviousRung() {
        assertClose(Milestone.progressToNext(minutes: 450), 0.5)
    }

    /// 境界ちょうどは次の区間の 0%。
    func testProgressResetsAtBoundary() {
        assertClose(Milestone.progressToNext(minutes: 60), 0.0)
    }

    func testProgressIsFullAfterLastRung() {
        assertClose(Milestone.progressToNext(minutes: 10_000 * 60), 1.0)
        assertClose(Milestone.progressToNext(minutes: 20_000 * 60), 1.0)
    }

    // MARK: - 越えた瞬間(祝うタイミング)

    func testCrossedHoursOnBoundary() {
        XCTAssertEqual(Milestone.crossedHours(fromMinutes: 59, toMinutes: 60), [1])
    }

    func testCrossedHoursNoneWithinSameRung() {
        XCTAssertEqual(Milestone.crossedHours(fromMinutes: 60, toMinutes: 299), [Int]())
    }

    /// 一度に複数の節目を越えたら全部(昇順)。
    func testCrossedHoursMultiple() {
        XCTAssertEqual(Milestone.crossedHours(fromMinutes: 0, toMinutes: 600), [1, 5, 10])
    }

    func testCrossedHoursEmptyWhenNoChange() {
        XCTAssertEqual(Milestone.crossedHours(fromMinutes: 300, toMinutes: 300), [Int]())
    }

    /// 逆行(記録の削除など)では祝わない。
    func testCrossedHoursEmptyWhenDecreasing() {
        XCTAssertEqual(Milestone.crossedHours(fromMinutes: 300, toMinutes: 200), [Int]())
    }
}
