import XCTest
import Foundation
@testable import BadNote

/// 手応えの向き(§3.2)。
///
/// **3 つの言葉に 3 つの違う意味を持たせるのはここ 1 か所。**
/// できた = 前に進む / 近づいた = 止まらない / 次にやる = 仕切り直し。
///
/// それまで `closer` と `next` はコード上まったく同じ扱い(`done` の連続を切るだけ)で、
/// 「近づいた」を付けても「次にやる」を付けても結果が変わらなかった。
final class MasteryTrendTests: XCTestCase {

    private func trend(_ results: [FocusResult?]) -> MasteryTrend {
        return MasteryTrend.of(recentResults: results)
    }

    // MARK: - 記録が無いとき

    func testEmptyHistoryIsSteady() {
        let result = trend([FocusResult?]())

        XCTAssertEqual(MasteryDirection.steady, result.direction)
        XCTAssertEqual(0, result.count)
    }

    // MARK: - できた(前に進む)

    func testConsecutiveDoneCountsForward() {
        let result = trend([.done, .done, .done])

        XCTAssertEqual(MasteryDirection.forward, result.direction)
        XCTAssertEqual(3, result.count)
    }

    /// **「近づいた」は連続を切らない。** ここが今回の変更の核心 ——
    /// 「近づいた」は前進なのだから、積み上げたものを戻さない。
    func testCloserDoesNotBreakTheForwardRun() {
        let result = trend([.done, .closer, .done, .done])

        XCTAssertEqual(MasteryDirection.forward, result.direction)
        XCTAssertEqual(3, result.count)
    }

    /// 先頭(最新)が「近づいた」でも中立。向きは次に見つかった値が決める。
    func testLeadingCloserIsNeutral() {
        let result = trend([.closer, .done, .done, .done])

        XCTAssertEqual(MasteryDirection.forward, result.direction)
        XCTAssertEqual(3, result.count)
    }

    /// **「近づいた」だけなら 0。** 中立は「進む」ではない ——
    /// 止まらないだけで、積み上がりもしない。
    func testCloserAloneIsSteady() {
        let result = trend([.closer, .closer, .closer])

        XCTAssertEqual(MasteryDirection.steady, result.direction)
        XCTAssertEqual(0, result.count)
    }

    /// 未入力も中立。「入力していない」を「できなかった」と解釈しない(§7.2 手応えは任意)。
    func testNilIsNeutral() {
        let result = trend([nil, .done, nil, .done, .done])

        XCTAssertEqual(MasteryDirection.forward, result.direction)
        XCTAssertEqual(3, result.count)
    }

    func testNilAndCloserOnlyIsSteady() {
        let result = trend([nil, .closer, nil])

        XCTAssertEqual(MasteryDirection.steady, result.direction)
        XCTAssertEqual(0, result.count)
    }

    // MARK: - 次にやる(仕切り直し)

    func testConsecutiveNextCountsRestart() {
        let result = trend([.next, .next, .next])

        XCTAssertEqual(MasteryDirection.restart, result.direction)
        XCTAssertEqual(3, result.count)
    }

    /// 「近づいた」は**どちらの向きにも**中立。仕切り直しの連続も切らない。
    func testCloserDoesNotBreakTheRestartRun() {
        let result = trend([.next, .closer, .next, .next])

        XCTAssertEqual(MasteryDirection.restart, result.direction)
        XCTAssertEqual(3, result.count)
    }

    // MARK: - できた と 次にやる は互いに打ち切る

    func testDoneBreaksTheRestartRun() {
        let result = trend([.next, .done, .done])

        XCTAssertEqual(MasteryDirection.restart, result.direction)
        XCTAssertEqual(1, result.count)
    }

    func testNextBreaksTheForwardRun() {
        let result = trend([.done, .next, .next, .next])

        XCTAssertEqual(MasteryDirection.forward, result.direction)
        XCTAssertEqual(1, result.count)
    }

    /// **古い連続は効かない。** 直近だけを見る。
    func testOnlyTheNewestRunCounts() {
        let result = trend([.done, .next, .done, .done, .done])

        XCTAssertEqual(MasteryDirection.forward, result.direction)
        XCTAssertEqual(1, result.count)
    }

    /// **先頭が最新。** 並びを逆にすると答えが変わる。
    func testTreatsFirstElementAsNewest() {
        let newestIsDone = trend([.done, .done, .next])
        let newestIsNext = trend([.next, .done, .done])

        XCTAssertEqual(MasteryDirection.forward, newestIsDone.direction)
        XCTAssertEqual(2, newestIsDone.count)
        XCTAssertEqual(MasteryDirection.restart, newestIsNext.direction)
        XCTAssertEqual(1, newestIsNext.count)
    }

    // MARK: - 対称性

    /// **できた と 次にやる を入れ替えると、向きだけが反転して数は変わらない。**
    /// 片方だけ直すバグを防ぐ。
    func testForwardAndRestartAreSymmetric() {
        let forward = trend([.done, .closer, .done, .next])
        let restart = trend([.next, .closer, .next, .done])

        XCTAssertEqual(MasteryDirection.forward, forward.direction)
        XCTAssertEqual(MasteryDirection.restart, restart.direction)
        XCTAssertEqual(forward.count, restart.count)
    }

    func testRequiredStreakIsThree() {
        XCTAssertEqual(3, MasteryTrend.requiredStreak)
    }
}
