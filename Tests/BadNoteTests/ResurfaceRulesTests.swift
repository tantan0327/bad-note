import XCTest
import Foundation
@testable import BadNote

/// 再浮上まわりの決まりごと(§7.3)。
final class ResurfaceRulesTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func issue(resurfaceCount: Int) -> Issue {
        return Issue(id: 1, coachWords: "A", resurfaceCount: resurfaceCount, createdAt: t0, updatedAt: t0)
    }

    // MARK: - 再開するレベル

    /// §7.3 再浮上時、レベルは前回の 1 つ下から再開する。
    func testResumesOneLevelBelow() throws {
        XCTAssertEqual(MasteryLevel.pattern, MasteryLevel.match.oneStepDown)
        XCTAssertEqual(MasteryLevel.drill, MasteryLevel.pattern.oneStepDown)
        XCTAssertEqual(MasteryLevel.solo, MasteryLevel.drill.oneStepDown)
    }

    /// **ゼロに戻さない。** Lv.1 の下は無いので Lv.1 のまま。
    func testDoesNotDropBelowFirstLevel() throws {
        XCTAssertEqual(MasteryLevel.solo, MasteryLevel.solo.oneStepDown)
    }

    // MARK: - よく戻ってくる課題(§7.3)

    func testBadgeThresholdIsThree() throws {
        XCTAssertEqual(3, Issue.frequentResurfaceThreshold)
    }

    /// 境界: 2 回ではバッジを出さない。
    func testNoBadgeBelowThreshold() throws {
        XCTAssertFalse(issue(resurfaceCount: 2).isFrequentlyResurfacing)
    }

    /// 境界: 3 回でバッジを出す。
    func testBadgeAtThreshold() throws {
        XCTAssertTrue(issue(resurfaceCount: 3).isFrequentlyResurfacing)
    }

    func testBadgeAboveThreshold() throws {
        XCTAssertTrue(issue(resurfaceCount: 5).isFrequentlyResurfacing)
    }

    func testNoBadgeForNeverResurfacedIssue() throws {
        XCTAssertFalse(issue(resurfaceCount: 0).isFrequentlyResurfacing)
    }

    // MARK: - 克服した(§7.3)

    /// **Lv.4 のときだけ克服できる。**
    func testCanOvercomeOnlyAtMatchLevel() throws {
        XCTAssertTrue(MasteryLevel.match.canOvercome)
        XCTAssertFalse(MasteryLevel.pattern.canOvercome)
        XCTAssertFalse(MasteryLevel.drill.canOvercome)
        XCTAssertFalse(MasteryLevel.solo.canOvercome)
    }
}
