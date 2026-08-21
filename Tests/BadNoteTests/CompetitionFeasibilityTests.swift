import XCTest
import Foundation
@testable import BadNote

/// 「この大会では厳しいかもしれません」の判定(§7.5)。
///
/// 習得コストと残り時間から**控えめに**提示する。アプリは警告を出さず、判断材料だけを置く。
final class CompetitionFeasibilityTests: XCTestCase {

    func testRequiredDaysByCost() throws {
        XCTAssertEqual(7, CompetitionFeasibility.requiredDays(forCost: 1))
        XCTAssertEqual(30, CompetitionFeasibility.requiredDays(forCost: 2))
        XCTAssertEqual(90, CompetitionFeasibility.requiredDays(forCost: 3))
    }

    /// コスト 3(シーズン単位)は 30 日では厳しい(§3.4)。
    func testHighCostIsTightForNearEvent() throws {
        XCTAssertTrue(CompetitionFeasibility.isTight(cost: 3, remainingDays: 30))
    }

    func testHighCostIsNotTightWithEnoughTime() throws {
        XCTAssertFalse(CompetitionFeasibility.isTight(cost: 3, remainingDays: 120))
    }

    /// 境界: 必要日数ちょうどなら厳しくない。
    func testExactlyEnoughTimeIsNotTight() throws {
        XCTAssertFalse(CompetitionFeasibility.isTight(cost: 2, remainingDays: 30))
    }

    func testOneDayShortIsTight() throws {
        XCTAssertTrue(CompetitionFeasibility.isTight(cost: 2, remainingDays: 29))
    }

    func testLowCostIsRarelyTight() throws {
        XCTAssertFalse(CompetitionFeasibility.isTight(cost: 1, remainingDays: 7))
    }

    /// **コスト未設定なら何も言わない。** 判断材料が無いのに警告を出さない。
    func testUnknownCostIsNeverTight() throws {
        XCTAssertFalse(CompetitionFeasibility.isTight(cost: nil, remainingDays: 1))
    }

    /// 大会が過ぎていれば判定しない。
    func testPastEventIsNotTight() throws {
        XCTAssertFalse(CompetitionFeasibility.isTight(cost: 3, remainingDays: -1))
    }
}
