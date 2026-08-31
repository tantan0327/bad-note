import XCTest
import Foundation
@testable import BadNote

/// カウントダウンの文言(§5.2)。
///
/// ホームと大会詳細に**同じコードが 2 つ**あったので 1 か所に寄せた
/// (`HomeView.remainingText` と `CompetitionDetailView.remainingText`)。
/// 片方だけ直る事故を防ぐ。
final class RemainingTextTests: XCTestCase {

    func testShowsDaysAndCount() {
        XCTAssertEqual("あと 42日 / 12回", RemainingText.text(remainingDays: 42, remainingPractices: 12))
    }

    /// **予定日が未設定なら回数を出さない。** 根拠のない数字を出さないため
    /// (画面はこれと別に、設定への導線を出す)。
    func testShowsDaysOnlyWhenTheCountIsUnknown() {
        XCTAssertEqual("あと 42日", RemainingText.text(remainingDays: 42, remainingPractices: nil))
    }

    /// 大会当日は日数ではなく「今日」。
    func testShowsTodayOnTheEventDay() {
        XCTAssertEqual("今日", RemainingText.text(remainingDays: 0, remainingPractices: nil))
    }

    /// 当日でも回数の欄は同じ形で続く(0 回と分かる)。
    func testShowsTodayWithTheCount() {
        XCTAssertEqual("今日 / 0回", RemainingText.text(remainingDays: 0, remainingPractices: 0))
    }

    /// 予定を決めた上で大会までに 1 日も無いときは **0回 と出す**。
    /// 未設定(日数だけ)と区別できることがこの画面での意味。
    func testShowsZeroWhenPlannedButNoneLeft() {
        XCTAssertEqual("あと 3日 / 0回", RemainingText.text(remainingDays: 3, remainingPractices: 0))
    }
}
