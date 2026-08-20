import XCTest
import Foundation
@testable import BadNote

/// 調整期の判定(§4.4 / §7.5)。
///
/// 大会直前に忘れていた課題を掘り返さないための期間。調整期の間は stale の
/// 評価自体をスキップし、ホームのセクションも隠す。
///
/// **種目ごとに独立させない。** 表示切り替え(8 週間)は種目ごとだが、
/// 調整期だけは「最も近い目標大会」を基準に全体で 1 つ(§7.5)。
///
/// 純粋関数。基準は `asOf` = 2023-11-14T22:13:20Z。
final class AdjustmentPeriodTests: XCTestCase {

    private let asOf = Date(timeIntervalSince1970: 1_700_000_000)
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func day(_ days: Double) -> Date {
        return Date(timeIntervalSince1970: 1_700_000_000.0 + days * 86_400.0)
    }

    private func competition(_ id: Int64, _ days: Double) -> Competition {
        return Competition(id: id, name: "大会\(id)", eventDate: day(days), createdAt: t0)
    }

    // MARK: - 閾値

    /// §4.4 目標大会の 2 週間前から。
    func testStandardLeadDaysIsFourteen() throws {
        XCTAssertEqual(14, AdjustmentPeriod.standardLeadDays)
    }

    func testLeadDaysCanBeOverridden() throws {
        let targets = [competition(1, 10)]

        XCTAssertFalse(AdjustmentPeriod.isActive(targets: targets, asOf: asOf, leadDays: 7))
        XCTAssertTrue(AdjustmentPeriod.isActive(targets: targets, asOf: asOf, leadDays: 14))
    }

    // MARK: - 目標大会が無いとき

    /// 大会なしでもアプリは成立する(§7.1)。調整期にはしない。
    func testNoTargetsIsNotAdjustmentPeriod() throws {
        XCTAssertFalse(AdjustmentPeriod.isActive(targets: [], asOf: asOf))
    }

    // MARK: - 境界

    /// 境界: ちょうど 14 日前から調整期。
    func testFourteenDaysBeforeIsAdjustmentPeriod() throws {
        XCTAssertTrue(AdjustmentPeriod.isActive(targets: [competition(1, 14)], asOf: asOf))
    }

    /// 境界: 15 日前はまだ調整期ではない。
    func testFifteenDaysBeforeIsNotAdjustmentPeriod() throws {
        XCTAssertFalse(AdjustmentPeriod.isActive(targets: [competition(1, 15)], asOf: asOf))
    }

    func testOneDayBeforeIsAdjustmentPeriod() throws {
        XCTAssertTrue(AdjustmentPeriod.isActive(targets: [competition(1, 1)], asOf: asOf))
    }

    /// 大会当日は調整期。当日いっぱい掘り返さない。
    func testEventDayIsAdjustmentPeriod() throws {
        XCTAssertTrue(AdjustmentPeriod.isActive(targets: [competition(1, 0)], asOf: asOf))
    }

    /// 過ぎた大会は調整期を作らない。終わったら stale の提示を再開する。
    func testPastEventIsNotAdjustmentPeriod() throws {
        XCTAssertFalse(AdjustmentPeriod.isActive(targets: [competition(1, -1)], asOf: asOf))
    }

    func testLongPastEventIsNotAdjustmentPeriod() throws {
        XCTAssertFalse(AdjustmentPeriod.isActive(targets: [competition(1, -60)], asOf: asOf))
    }

    // MARK: - 最も近い大会で決まる

    /// §7.5 調整期の判定だけは「最も近い目標大会」を基準にする。
    func testNearestTargetDecidesAdjustmentPeriod() throws {
        let targets = [competition(1, 30), competition(2, 10)]

        XCTAssertTrue(AdjustmentPeriod.isActive(targets: targets, asOf: asOf), "近い方の 10 日で判定する")
    }

    func testFarTargetsDoNotTriggerAdjustmentPeriod() throws {
        let targets = [competition(1, 20), competition(2, 40)]

        XCTAssertFalse(AdjustmentPeriod.isActive(targets: targets, asOf: asOf))
    }

    /// 種目ごとに独立させない。片方の種目が調整期に入れば全体が調整期。
    func testAdjustmentPeriodIsGlobalNotPerDiscipline() throws {
        let singlesTarget = competition(1, 40)
        let doublesTarget = competition(2, 5)

        XCTAssertTrue(AdjustmentPeriod.isActive(targets: [singlesTarget, doublesTarget], asOf: asOf))
    }

    /// 過ぎた大会は無視して、次の大会で判定する。
    func testPastTargetIsIgnoredWhenFutureTargetExists() throws {
        let targets = [competition(1, -3), competition(2, 30)]

        XCTAssertFalse(AdjustmentPeriod.isActive(targets: targets, asOf: asOf))
    }

    func testPastTargetIsIgnoredWhenNearFutureTargetExists() throws {
        let targets = [competition(1, -3), competition(2, 7)]

        XCTAssertTrue(AdjustmentPeriod.isActive(targets: targets, asOf: asOf))
    }

    // MARK: - 最も近い目標大会

    func testNearestTargetReturnsClosestFutureCompetition() throws {
        let targets = [competition(1, 30), competition(2, 10), competition(3, 20)]

        let nearest = try XCTUnwrap(AdjustmentPeriod.nearestTarget(targets, asOf: asOf))

        XCTAssertEqual(Int64(2), nearest.id)
    }

    func testNearestTargetIgnoresPastCompetitions() throws {
        let targets = [competition(1, -1), competition(2, 30)]

        let nearest = try XCTUnwrap(AdjustmentPeriod.nearestTarget(targets, asOf: asOf))

        XCTAssertEqual(Int64(2), nearest.id)
    }

    func testNearestTargetIncludesToday() throws {
        let targets = [competition(1, 0), competition(2, 5)]

        let nearest = try XCTUnwrap(AdjustmentPeriod.nearestTarget(targets, asOf: asOf))

        XCTAssertEqual(Int64(1), nearest.id)
    }

    func testNearestTargetIsNilWhenAllPast() throws {
        let targets = [competition(1, -1), competition(2, -30)]

        XCTAssertNil(AdjustmentPeriod.nearestTarget(targets, asOf: asOf))
    }

    func testNearestTargetIsNilForEmptyList() throws {
        XCTAssertNil(AdjustmentPeriod.nearestTarget([], asOf: asOf))
    }
}
