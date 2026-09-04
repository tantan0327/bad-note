import XCTest
import Foundation
@testable import BadNote

/// 課題の「今どこにいるか」と、本人に聞く 1 手(§3.2)。
///
/// **画面に出す文と、提案を出す判定は同じ値から作る。**
/// 別々に数えると「進んでいます」と出ているのに提案が出ない、が起きる。
final class MasteryStandingTests: XCTestCase {

    private func standing(_ results: [FocusResult?], _ level: MasteryLevel) -> MasteryStanding {
        return MasteryStanding.of(recentResults: results, level: level)
    }

    private func issue(level: MasteryLevel,
                       levelUpDeclined: Int? = nil,
                       stepDownDeclined: Int? = nil,
                       status: IssueStatus = .active) -> Issue {
        return Issue(id: 1,
                     coachWords: "ハイクリアが浅い",
                     masteryLevel: level,
                     status: status,
                     levelUpDeclinedLevel: levelUpDeclined,
                     stepDownDeclinedLevel: stepDownDeclined,
                     createdAt: Date(),
                     updatedAt: Date())
    }

    // MARK: - 上げる

    func testSuggestsLevelUpAfterThreeDone() throws {
        let result = standing([.done, .done, .done], .solo)

        var offer: MasteryOffer = try XCTUnwrap(result.offer)
        XCTAssertEqual(MasteryOfferKind.levelUp, offer.kind)
        XCTAssertEqual(MasteryLevel.drill, offer.level)
    }

    /// **2 回では提案しないが、向きは forward。**
    /// 「進んでいます」の文は出て、提案はまだ出ない境界。
    func testShowsForwardWithoutAnOfferBelowTheThreshold() {
        let result = standing([.done, .done], .solo)

        XCTAssertEqual(MasteryDirection.forward, result.trend.direction)
        XCTAssertNil(result.offer)
    }

    // MARK: - 克服(梯子の最後)

    /// **Lv.4 で できた が続いたら「克服した」への扉を出す。**
    /// それまで Lv.4 に達しても本人が気づく手がかりが無かった。
    func testOffersOvercomeAtTheTopLevel() throws {
        let result = standing([.done, .done, .done], .match)

        var offer: MasteryOffer = try XCTUnwrap(result.offer)
        XCTAssertEqual(MasteryOfferKind.overcome, offer.kind)
        XCTAssertEqual(MasteryLevel.match, offer.level)
    }

    /// アーカイブ済み(克服済み)には何も出さない。梯子は登り切っている。
    func testOffersNothingForArchivedIssues() {
        let result = MasteryStanding.of(recentResults: [.done, .done, .done],
                                        issue: issue(level: .match, status: .archived))

        XCTAssertNil(result.offer)
    }

    // MARK: - 戻す

    func testSuggestsStepDownAfterThreeNext() throws {
        let result = standing([.next, .next, .next], .pattern)

        var offer: MasteryOffer = try XCTUnwrap(result.offer)
        XCTAssertEqual(MasteryOfferKind.stepDown, offer.kind)
        XCTAssertEqual(MasteryLevel.drill, offer.level)
    }

    /// **Lv.1 では出さない。** 下が無い。
    func testDoesNotSuggestStepDownAtTheBottom() {
        let result = standing([.next, .next, .next], .solo)

        XCTAssertEqual(MasteryDirection.restart, result.trend.direction)
        XCTAssertNil(result.offer)
    }

    func testDoesNotSuggestStepDownBelowTheThreshold() {
        XCTAssertNil(standing([.next, .next], .pattern).offer)
    }

    // MARK: - 断った記録

    func testDoesNotRepeatALevelUpThatWasDeclined() {
        let result = MasteryStanding.of(recentResults: [.done, .done, .done],
                                        issue: issue(level: .solo, levelUpDeclined: 1))

        XCTAssertNil(result.offer)
    }

    /// 段が変われば、断った記録は現在のレベルと一致しなくなるのでまた提案できる。
    func testSuggestsAgainAfterTheLevelChanged() {
        let result = MasteryStanding.of(recentResults: [.done, .done, .done],
                                        issue: issue(level: .drill, levelUpDeclined: 1))

        XCTAssertNotNil(result.offer)
    }

    func testDoesNotRepeatAStepDownThatWasDeclined() {
        let result = MasteryStanding.of(recentResults: [.next, .next, .next],
                                        issue: issue(level: .pattern, stepDownDeclined: 3))

        XCTAssertNil(result.offer)
    }

    /// **上げるのを断っても、戻す提案は止まらない。** 列を分けた理由そのもの。
    func testDecliningALevelUpDoesNotSilenceStepDown() throws {
        let result = MasteryStanding.of(recentResults: [.next, .next, .next],
                                        issue: issue(level: .pattern, levelUpDeclined: 3))

        var offer: MasteryOffer = try XCTUnwrap(result.offer)
        XCTAssertEqual(MasteryOfferKind.stepDown, offer.kind)
    }

    func testDecliningAStepDownDoesNotSilenceLevelUp() throws {
        let result = MasteryStanding.of(recentResults: [.done, .done, .done],
                                        issue: issue(level: .pattern, stepDownDeclined: 3))

        var offer: MasteryOffer = try XCTUnwrap(result.offer)
        XCTAssertEqual(MasteryOfferKind.levelUp, offer.kind)
    }

    // MARK: - 何も無いとき

    func testSteadyOffersNothing() {
        let result = standing([.closer, .closer], .drill)

        XCTAssertEqual(MasteryDirection.steady, result.trend.direction)
        XCTAssertNil(result.offer)
    }

    func testEmptyHistoryOffersNothing() {
        let result = standing([FocusResult?](), .drill)

        XCTAssertNil(result.offer)
    }

    // MARK: - 現在地は入力どおり

    func testKeepsTheGivenLevel() {
        XCTAssertEqual(MasteryLevel.pattern, standing([.done], .pattern).level)
    }

    /// **提案は同時に 2 つ出ない。** 向きが 1 つなので構造的に起きないが、
    /// 判定を 2 か所に分けたときに壊れるので固定する。
    func testNeverOffersTwoThingsAtOnce() {
        // どの組み合わせでも offer は高々 1 つ(型が Optional なので、
        // ここで確かめるのは「向きが両立しない」こと)
        let forward = standing([.done, .done, .done], .drill)
        let restart = standing([.next, .next, .next], .drill)

        XCTAssertEqual(MasteryDirection.forward, forward.trend.direction)
        XCTAssertEqual(MasteryDirection.restart, restart.trend.direction)
        XCTAssertNotEqual(forward.trend.direction, restart.trend.direction)
    }
}
