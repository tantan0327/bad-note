import XCTest
import Foundation
@testable import BadNote

/// 練習ログ入力の「保存できるか」(§7.2)。
///
/// **必須項目は作らない**(入力項目は原則すべて任意)。止めるのは
/// **すべて空のまま保存**したときだけ —— 練習ログは後から直す画面が無いので、
/// 0 分・種類なし・手応えなしの行が練習回数と積み上げに残り続ける。
///
/// DB には触らない。`canSave` は入力だけを見る純粋な判定。
final class PracticeLogModelTests: XCTestCase {

    private func issue(id: Int64) -> Issue {
        return Issue(id: id,
                     coachWords: "ハイクリアが浅い",
                     masteryLevel: MasteryLevel.solo,
                     status: IssueStatus.active,
                     createdAt: Date(),
                     updatedAt: Date())
    }

    // MARK: - 何も入れていない

    func testCannotSaveWhenNothingEntered() {
        let model = PracticeLogModel()

        XCTAssertFalse(model.canSave)
    }

    /// 重点が読み込まれているだけでは「入力した」ことにならない。
    /// 開いて閉じただけで 0 分の行が残るのを防ぐ境界。
    func testCannotSaveWithFocusRowsButNoResults() {
        let model = PracticeLogModel()
        model.focusInputs = [PracticeLogModel.FocusInput(issue: issue(id: 1), result: nil),
                             PracticeLogModel.FocusInput(issue: issue(id: 2), result: nil)]

        XCTAssertFalse(model.canSave)
    }

    /// 「0」や空白だけでは保存できない。`minutes` は数値にできない文字列を 0 にする。
    func testCannotSaveWithZeroMinutes() {
        let model = PracticeLogModel()
        model.minutesText = "0"

        XCTAssertFalse(model.canSave)
    }

    func testCannotSaveWithBlankCoachWordsDraft() {
        let model = PracticeLogModel()
        model.coachWordsDraft = "   "

        XCTAssertFalse(model.canSave)
    }

    // MARK: - どれか 1 つ入っていれば保存できる

    func testCanSaveWithMinutesOnly() {
        let model = PracticeLogModel()
        model.minutesText = "90"

        XCTAssertTrue(model.canSave)
    }

    /// 時間を忘れても種類だけは覚えている、はありうる。
    func testCanSaveWithKindOnly() {
        let model = PracticeLogModel()
        model.kind = PracticeKind.whole

        XCTAssertTrue(model.canSave)
    }

    /// 手応えだけ付けて閉じるのも記録として成立する(時間は任意)。
    func testCanSaveWithFocusResultOnly() {
        let model = PracticeLogModel()
        model.focusInputs = [PracticeLogModel.FocusInput(issue: issue(id: 1), result: nil),
                             PracticeLogModel.FocusInput(issue: issue(id: 2), result: FocusResult.done)]

        XCTAssertTrue(model.canSave)
    }

    func testCanSaveWithAddedCoachWordsOnly() {
        let model = PracticeLogModel()
        model.addedCoachWords = ["足が止まっていた"]

        XCTAssertTrue(model.canSave)
    }

    /// 「＋」を押し忘れた 1 行も入力のうち(`pendingCoachWords` と同じ扱い)。
    func testCanSaveWithUncommittedCoachWordsDraft() {
        let model = PracticeLogModel()
        model.coachWordsDraft = "足が止まっていた"

        XCTAssertTrue(model.canSave)
    }
}
