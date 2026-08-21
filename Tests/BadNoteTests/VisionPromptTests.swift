import XCTest
import Foundation
@testable import BadNote

/// めざす姿を書くよう促すかの判定(§7.1)。
///
/// **初回は促さない。数回使った後に 1 度だけ促す。**
/// 使い始めに「まず理想像を書いてください」と出すと、書けなくて止まる。
///
/// 純粋関数。
final class VisionPromptTests: XCTestCase {

    private let empty = Vision()
    private let written = Vision(body: "相手に的を絞らせないシングルスプレーヤー",
                                 updatedAt: Date(timeIntervalSince1970: 1_700_000_000))

    func testRequiredPracticeCountIsThree() throws {
        XCTAssertEqual(3, VisionPrompt.requiredPracticeCount)
    }

    /// 初回(練習 0 回)は促さない。
    func testDoesNotPromptOnFirstUse() throws {
        XCTAssertFalse(VisionPrompt.shouldPrompt(vision: empty, practiceCount: 0, alreadyPrompted: false))
    }

    /// 境界: 2 回ではまだ促さない。
    func testDoesNotPromptBeforeThreshold() throws {
        XCTAssertFalse(VisionPrompt.shouldPrompt(vision: empty, practiceCount: 2, alreadyPrompted: false))
    }

    /// 境界: 3 回目から促す。
    func testPromptsAtThreshold() throws {
        XCTAssertTrue(VisionPrompt.shouldPrompt(vision: empty, practiceCount: 3, alreadyPrompted: false))
    }

    /// 一度促したらもう促さない。
    func testDoesNotPromptTwice() throws {
        XCTAssertFalse(VisionPrompt.shouldPrompt(vision: empty, practiceCount: 10, alreadyPrompted: true))
    }

    /// 既に書いてあれば促さない。
    func testDoesNotPromptWhenVisionIsWritten() throws {
        XCTAssertFalse(VisionPrompt.shouldPrompt(vision: written, practiceCount: 10, alreadyPrompted: false))
    }

    /// 画像だけでも「書いてある」とみなす(§7.1 テキスト + 任意で画像)。
    func testDoesNotPromptWhenOnlyImageIsSet() throws {
        let imageOnly = Vision(body: "", imagePath: "vision/photo.jpg")

        XCTAssertFalse(VisionPrompt.shouldPrompt(vision: imageOnly, practiceCount: 10, alreadyPrompted: false))
    }

    /// 書いた後に消しても、一度促していれば蒸し返さない。
    func testDoesNotPromptAgainAfterClearing() throws {
        XCTAssertFalse(VisionPrompt.shouldPrompt(vision: empty, practiceCount: 20, alreadyPrompted: true))
    }
}
