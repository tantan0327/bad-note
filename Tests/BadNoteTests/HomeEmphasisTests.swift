import XCTest
import Foundation
@testable import BadNote

/// ホームの主数値の切り替え(§5.1)。
///
/// 目標大会の 8 週間前を境に、大きく出す数字を入れ替える。同じデータで見せ方だけ変える。
/// 遠い時期に日数を大きく出すと「まだ先だ」になって逆効果、という判断。
final class HomeEmphasisTests: XCTestCase {

    private let asOf = Date(timeIntervalSince1970: 1_700_000_000)

    private func day(_ days: Double) -> Date {
        return Date(timeIntervalSince1970: 1_700_000_000.0 + days * 86_400.0)
    }

    func testSwitchDaysIsEightWeeks() throws {
        XCTAssertEqual(56, HomeEmphasis.switchDays)
    }

    /// 8 週間より前は積み上げ(今月の練習時間 / レベルアップ回数)を大きく出す。
    func testFarFromEventEmphasizesBuildUp() throws {
        XCTAssertEqual(HomeEmphasis.buildUp, HomeEmphasis.forEvent(day(70), asOf: asOf))
    }

    /// 境界: 57 日前はまだ積み上げ。
    func testFiftySevenDaysBeforeEmphasizesBuildUp() throws {
        XCTAssertEqual(HomeEmphasis.buildUp, HomeEmphasis.forEvent(day(57), asOf: asOf))
    }

    /// 境界: 56 日前(8 週間ちょうど)からカウントダウン。
    func testFiftySixDaysBeforeEmphasizesCountdown() throws {
        XCTAssertEqual(HomeEmphasis.countdown, HomeEmphasis.forEvent(day(56), asOf: asOf))
    }

    func testNearEventEmphasizesCountdown() throws {
        XCTAssertEqual(HomeEmphasis.countdown, HomeEmphasis.forEvent(day(3), asOf: asOf))
    }

    func testEventDayEmphasizesCountdown() throws {
        XCTAssertEqual(HomeEmphasis.countdown, HomeEmphasis.forEvent(asOf, asOf: asOf))
    }

    /// 目標大会が無ければ積み上げを見せる(大会なしでもアプリは成立する)。
    func testNoEventEmphasizesBuildUp() throws {
        XCTAssertEqual(HomeEmphasis.buildUp, HomeEmphasis.forEvent(nil, asOf: asOf))
    }

    /// 過ぎた大会はカウントダウンの対象にしない。
    func testPastEventEmphasizesBuildUp() throws {
        XCTAssertEqual(HomeEmphasis.buildUp, HomeEmphasis.forEvent(day(-1), asOf: asOf))
    }
}
