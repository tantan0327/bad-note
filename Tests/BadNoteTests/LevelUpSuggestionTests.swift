import XCTest
import Foundation
@testable import BadNote

/// レベルアップ提案の判定(§3.2)。
///
/// 「同じ課題で手応え `done` が 3 回連続したら、Lv を上げるか 1 度だけ提案する」。
/// 自動では上げない。判定するだけで、承認するのはユーザー。
///
/// 純粋関数。手応え履歴は**新しい順**で受け取る。
final class LevelUpSuggestionTests: XCTestCase {

    // MARK: - 連続数

    func testStreakIsZeroForEmptyHistory() throws {
        let count = LevelUpSuggestion.consecutiveDoneCount(recentResults: [])

        XCTAssertEqual(0, count)
    }

    func testStreakCountsConsecutiveDoneFromNewest() throws {
        let results: [FocusResult?] = [FocusResult.done, FocusResult.done, FocusResult.done]

        let count = LevelUpSuggestion.consecutiveDoneCount(recentResults: results)

        XCTAssertEqual(3, count)
    }

    /// closer が挟まったらそこで打ち切り。
    func testStreakStopsAtCloser() throws {
        let results: [FocusResult?] = [FocusResult.done, FocusResult.done, FocusResult.closer, FocusResult.done]

        let count = LevelUpSuggestion.consecutiveDoneCount(recentResults: results)

        XCTAssertEqual(2, count)
    }

    /// next も同じく打ち切り。
    func testStreakStopsAtNext() throws {
        let results: [FocusResult?] = [FocusResult.done, FocusResult.next, FocusResult.done]

        let count = LevelUpSuggestion.consecutiveDoneCount(recentResults: results)

        XCTAssertEqual(1, count)
    }

    /// nil(未入力)は連続を切らない。数にも入れず、飛ばして次を見る。
    func testStreakSkipsNilResults() throws {
        let results: [FocusResult?] = [FocusResult.done, nil, FocusResult.done, FocusResult.done]

        let count = LevelUpSuggestion.consecutiveDoneCount(recentResults: results)

        XCTAssertEqual(3, count)
    }

    func testStreakSkipsLeadingNilResults() throws {
        let results: [FocusResult?] = [nil, nil, FocusResult.done, FocusResult.done, FocusResult.done]

        let count = LevelUpSuggestion.consecutiveDoneCount(recentResults: results)

        XCTAssertEqual(3, count)
    }

    func testStreakIsZeroWhenNewestIsCloser() throws {
        let results: [FocusResult?] = [FocusResult.closer, FocusResult.done, FocusResult.done, FocusResult.done]

        let count = LevelUpSuggestion.consecutiveDoneCount(recentResults: results)

        XCTAssertEqual(0, count)
    }

    /// 未入力しか無いなら連続 0。提案の材料にならない。
    func testStreakIsZeroForAllNilHistory() throws {
        let results: [FocusResult?] = [nil, nil, nil]

        let count = LevelUpSuggestion.consecutiveDoneCount(recentResults: results)

        XCTAssertEqual(0, count)
    }

    // MARK: - 提案

    /// §3.2 done が 3 回連続したら次の Lv を提案する。
    func testSuggestsNextLevelAfterThreeConsecutiveDone() throws {
        let results: [FocusResult?] = [FocusResult.done, FocusResult.done, FocusResult.done]

        let suggested = LevelUpSuggestion.suggestedLevel(recentResults: results, currentLevel: .solo)

        XCTAssertEqual(MasteryLevel.drill, suggested)
    }

    func testDoesNotSuggestAfterTwoDone() throws {
        let results: [FocusResult?] = [FocusResult.done, FocusResult.done]

        let suggested = LevelUpSuggestion.suggestedLevel(recentResults: results, currentLevel: .solo)

        XCTAssertNil(suggested)
    }

    func testSuggestsWithMoreThanThreeDone() throws {
        let results: [FocusResult?] = [FocusResult.done, FocusResult.done, FocusResult.done, FocusResult.done]

        let suggested = LevelUpSuggestion.suggestedLevel(recentResults: results, currentLevel: .drill)

        XCTAssertEqual(MasteryLevel.pattern, suggested)
    }

    func testSuggestsFromPatternToMatch() throws {
        let results: [FocusResult?] = [FocusResult.done, FocusResult.done, FocusResult.done]

        let suggested = LevelUpSuggestion.suggestedLevel(recentResults: results, currentLevel: .pattern)

        XCTAssertEqual(MasteryLevel.match, suggested)
    }

    /// §3.2 Lv.4(試合)が上限。上げ先が無いので提案しない。
    func testDoesNotSuggestAtMatchLevel() throws {
        let results: [FocusResult?] = [FocusResult.done, FocusResult.done, FocusResult.done]

        let suggested = LevelUpSuggestion.suggestedLevel(recentResults: results, currentLevel: .match)

        XCTAssertNil(suggested)
    }

    func testDoesNotSuggestWhenCloserBreaksStreak() throws {
        let results: [FocusResult?] = [FocusResult.done, FocusResult.closer, FocusResult.done, FocusResult.done]

        let suggested = LevelUpSuggestion.suggestedLevel(recentResults: results, currentLevel: .solo)

        XCTAssertNil(suggested)
    }

    /// 未入力を挟んでいても 3 回連続とみなす。
    func testSuggestsWhenNilResultsAreSkipped() throws {
        let results: [FocusResult?] = [FocusResult.done, nil, FocusResult.done, nil, FocusResult.done]

        let suggested = LevelUpSuggestion.suggestedLevel(recentResults: results, currentLevel: .solo)

        XCTAssertEqual(MasteryLevel.drill, suggested)
    }

    func testDoesNotSuggestForEmptyHistory() throws {
        let suggested = LevelUpSuggestion.suggestedLevel(recentResults: [], currentLevel: .solo)

        XCTAssertNil(suggested)
    }

    /// 古い方に 3 連続があっても、直近が切れていれば提案しない。
    func testOnlyTheNewestStreakMatters() throws {
        let results: [FocusResult?] = [
            FocusResult.done,
            FocusResult.closer,
            FocusResult.done,
            FocusResult.done,
            FocusResult.done,
        ]

        let suggested = LevelUpSuggestion.suggestedLevel(recentResults: results, currentLevel: .solo)

        XCTAssertNil(suggested)
    }

    /// 配列の先頭が最新。順序を逆に渡すと結果が変わる。
    func testTreatsFirstElementAsNewest() throws {
        let newestIsCloser: [FocusResult?] = [FocusResult.closer, FocusResult.done, FocusResult.done, FocusResult.done]
        let oldestIsCloser: [FocusResult?] = [FocusResult.done, FocusResult.done, FocusResult.done, FocusResult.closer]

        XCTAssertNil(LevelUpSuggestion.suggestedLevel(recentResults: newestIsCloser, currentLevel: .solo))
        XCTAssertEqual(MasteryLevel.drill,
                       LevelUpSuggestion.suggestedLevel(recentResults: oldestIsCloser, currentLevel: .solo))
    }

    // MARK: - 1 度だけ提案する(§3.2)

    private func issue(level: MasteryLevel, declined: Int? = nil) -> Issue {
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        return Issue(id: 1,
                     coachWords: "A",
                     masteryLevel: level,
                     levelUpDeclinedLevel: declined,
                     createdAt: t0,
                     updatedAt: t0)
    }

    private var threeDone: [FocusResult?] {
        return [FocusResult.done, FocusResult.done, FocusResult.done]
    }

    func testSuggestsForIssueThatHasNotDeclined() throws {
        let suggested = LevelUpSuggestion.suggestedLevel(recentResults: threeDone, for: issue(level: .solo))

        XCTAssertEqual(MasteryLevel.drill, suggested)
    }

    /// 同じレベルで一度断られていたら、もう聞かない。
    func testDoesNotSuggestAgainAtDeclinedLevel() throws {
        let suggested = LevelUpSuggestion.suggestedLevel(recentResults: threeDone,
                                                         for: issue(level: .solo, declined: 1))

        XCTAssertNil(suggested)
    }

    /// レベルが上がったら、また提案してよい。
    func testSuggestsAgainAfterLevelChanged() throws {
        let suggested = LevelUpSuggestion.suggestedLevel(recentResults: threeDone,
                                                         for: issue(level: .drill, declined: 1))

        XCTAssertEqual(MasteryLevel.pattern, suggested)
    }

    func testDoesNotSuggestForIssueWithoutStreak() throws {
        let suggested = LevelUpSuggestion.suggestedLevel(recentResults: [FocusResult.done],
                                                         for: issue(level: .solo))

        XCTAssertNil(suggested)
    }
}
