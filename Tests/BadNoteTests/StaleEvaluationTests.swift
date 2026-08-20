import XCTest
import Foundation
@testable import BadNote

/// stale(しばらく触れていない課題)の判定(§4.2)。
///
/// 純粋関数。課題 1 件分の情報と判定基準日から、stale かどうかと理由を返す。
/// 判定するだけで、優先度は書き換えない(§4.3 自動で優先度を書き換えない)。
///
/// 基準は `asOf` = 2023-11-14T22:13:20Z。
final class StaleEvaluationTests: XCTestCase {

    private let asOf = Date(timeIntervalSince1970: 1_700_000_000)

    /// asOf から days 日ずらした日付。
    private func day(_ days: Double) -> Date {
        return Date(timeIntervalSince1970: 1_700_000_000.0 + days * 86_400.0)
    }

    // MARK: - 閾値

    /// §4.2 初期値: stale_days=21 / stale_practice_count=6
    func testStandardThresholds() throws {
        XCTAssertEqual(21, StaleThresholds.standard.days)
        XCTAssertEqual(6, StaleThresholds.standard.practiceCount)
    }

    /// app_meta で調整できるように、閾値は差し替えられる。
    func testThresholdsCanBeOverridden() throws {
        let thresholds = StaleThresholds(days: 14, practiceCount: 3)

        let reason = StaleEvaluation.reason(status: .inbox,
                                            tier: .someday,
                                            createdAt: day(-14),
                                            focusCount: 0,
                                            practiceCountSinceLeavingFocus: 0,
                                            asOf: asOf,
                                            thresholds: thresholds)

        XCTAssertEqual(StaleReason.neverFocused, reason, "14 日に下げれば 14 日で該当する")
    }

    func testShorterThresholdDoesNotChangeStandard() throws {
        _ = StaleThresholds(days: 14, practiceCount: 3)

        XCTAssertEqual(21, StaleThresholds.standard.days)
    }

    // MARK: - 対象外

    /// §4.2 archived は対象外。
    func testArchivedIssueIsNeverStale() throws {
        let reason = StaleEvaluation.reason(status: .archived,
                                            tier: .someday,
                                            createdAt: day(-100),
                                            focusCount: 0,
                                            practiceCountSinceLeavingFocus: 0,
                                            asOf: asOf)

        XCTAssertNil(reason, "定着した課題は掘り返さない")
    }

    /// §4.2 現に focus にある課題は対象外。今週やっているものを「触れていない」とは言わない。
    func testCurrentlyFocusedIssueIsNeverStale() throws {
        let reason = StaleEvaluation.reason(status: .active,
                                            tier: .focus,
                                            createdAt: day(-100),
                                            focusCount: 0,
                                            practiceCountSinceLeavingFocus: 100,
                                            asOf: asOf)

        XCTAssertNil(reason)
    }

    func testInboxIssueCanBeStale() throws {
        let reason = StaleEvaluation.reason(status: .inbox,
                                            tier: .someday,
                                            createdAt: day(-21),
                                            focusCount: 0,
                                            practiceCountSinceLeavingFocus: 0,
                                            asOf: asOf)

        XCTAssertEqual(StaleReason.neverFocused, reason)
    }

    func testActiveIssueCanBeStale() throws {
        let reason = StaleEvaluation.reason(status: .active,
                                            tier: .next,
                                            createdAt: day(-21),
                                            focusCount: 0,
                                            practiceCountSinceLeavingFocus: 0,
                                            asOf: asOf)

        XCTAssertEqual(StaleReason.neverFocused, reason)
    }

    // MARK: - never_focused

    /// §4.2 focus に一度も入らないまま stale_days 以上経過。
    /// §4.1 の最頻ケース(インボックスに入れたきり埋もれた課題)。
    func testNeverFocusedAfterThresholdDays() throws {
        let reason = StaleEvaluation.reason(status: .inbox,
                                            tier: .someday,
                                            createdAt: day(-28),
                                            focusCount: 0,
                                            practiceCountSinceLeavingFocus: 0,
                                            asOf: asOf)

        XCTAssertEqual(StaleReason.neverFocused, reason)
    }

    /// 境界: ちょうど 21 日は「21 日以上前」に含む。
    func testNeverFocusedIsStaleExactlyAtThreshold() throws {
        let reason = StaleEvaluation.reason(status: .inbox,
                                            tier: .someday,
                                            createdAt: day(-21),
                                            focusCount: 0,
                                            practiceCountSinceLeavingFocus: 0,
                                            asOf: asOf)

        XCTAssertEqual(StaleReason.neverFocused, reason)
    }

    /// 境界: 20 日ではまだ該当しない。
    func testNeverFocusedIsNotStaleBeforeThreshold() throws {
        let reason = StaleEvaluation.reason(status: .inbox,
                                            tier: .someday,
                                            createdAt: day(-20),
                                            focusCount: 0,
                                            practiceCountSinceLeavingFocus: 0,
                                            asOf: asOf)

        XCTAssertNil(reason)
    }

    /// 一度でも focus に入っていれば never_focused ではない。
    func testFocusedIssueIsNotNeverFocused() throws {
        let reason = StaleEvaluation.reason(status: .active,
                                            tier: .next,
                                            createdAt: day(-100),
                                            focusCount: 1,
                                            practiceCountSinceLeavingFocus: 0,
                                            asOf: asOf)

        XCTAssertNil(reason, "focus 経験があり、外れてからの練習も無い")
    }

    /// focus 未経験なら、練習回数がいくら多くても left_focus にはならない。
    func testNeverFocusedIssueIsNotJudgedByPracticeCount() throws {
        let reason = StaleEvaluation.reason(status: .inbox,
                                            tier: .someday,
                                            createdAt: day(-1),
                                            focusCount: 0,
                                            practiceCountSinceLeavingFocus: 100,
                                            asOf: asOf)

        XCTAssertNil(reason, "登録 1 日目の課題を stale にしない")
    }

    // MARK: - left_focus

    /// §4.2 focus を外れてからの練習が stale_practice_count 以上。
    func testLeftFocusAfterThresholdPractices() throws {
        let reason = StaleEvaluation.reason(status: .active,
                                            tier: .next,
                                            createdAt: day(-100),
                                            focusCount: 2,
                                            practiceCountSinceLeavingFocus: 8,
                                            asOf: asOf)

        XCTAssertEqual(StaleReason.leftFocus, reason)
    }

    /// 境界: ちょうど 6 回は該当する。
    func testLeftFocusIsStaleExactlyAtThreshold() throws {
        let reason = StaleEvaluation.reason(status: .active,
                                            tier: .next,
                                            createdAt: day(-100),
                                            focusCount: 1,
                                            practiceCountSinceLeavingFocus: 6,
                                            asOf: asOf)

        XCTAssertEqual(StaleReason.leftFocus, reason)
    }

    /// 境界: 5 回ではまだ該当しない。
    func testLeftFocusIsNotStaleBelowThreshold() throws {
        let reason = StaleEvaluation.reason(status: .active,
                                            tier: .next,
                                            createdAt: day(-100),
                                            focusCount: 1,
                                            practiceCountSinceLeavingFocus: 5,
                                            asOf: asOf)

        XCTAssertNil(reason)
    }

    /// 登録が最近でも、focus を外れて練習が進んでいれば該当する。
    func testLeftFocusIgnoresCreationDate() throws {
        let reason = StaleEvaluation.reason(status: .active,
                                            tier: .someday,
                                            createdAt: day(-1),
                                            focusCount: 1,
                                            practiceCountSinceLeavingFocus: 6,
                                            asOf: asOf)

        XCTAssertEqual(StaleReason.leftFocus, reason)
    }

    // MARK: - 理由の DB 表現

    /// stale_flag.reason に入る値(§6)。
    func testReasonRawValuesMatchSchema() throws {
        XCTAssertEqual("never_focused", StaleReason.neverFocused.rawValue)
        XCTAssertEqual("left_focus", StaleReason.leftFocus.rawValue)
    }

    // MARK: - no_update(§4.2 の 3 つ目)

    /// 重点を経験していて、外れてからの練習は少ないが、更新が途絶えている。
    func testNoUpdateAfterThresholdDays() throws {
        let reason = StaleEvaluation.reason(status: .active,
                                            tier: .next,
                                            createdAt: day(-100),
                                            focusCount: 1,
                                            practiceCountSinceLeavingFocus: 0,
                                            updatedAt: day(-30),
                                            asOf: asOf)

        XCTAssertEqual(StaleReason.noUpdate, reason)
    }

    /// 境界: 21 日ちょうどで該当。
    func testNoUpdateIsStaleExactlyAtThreshold() throws {
        let reason = StaleEvaluation.reason(status: .active,
                                            tier: .next,
                                            createdAt: day(-100),
                                            focusCount: 1,
                                            practiceCountSinceLeavingFocus: 0,
                                            updatedAt: day(-21),
                                            asOf: asOf)

        XCTAssertEqual(StaleReason.noUpdate, reason)
    }

    func testNoUpdateIsNotStaleBeforeThreshold() throws {
        let reason = StaleEvaluation.reason(status: .active,
                                            tier: .next,
                                            createdAt: day(-100),
                                            focusCount: 1,
                                            practiceCountSinceLeavingFocus: 0,
                                            updatedAt: day(-20),
                                            asOf: asOf)

        XCTAssertNil(reason)
    }

    /// §4.2 複数該当時は never_focused > left_focus > no_update の優先。
    /// never_focused が §4.1 の最頻ケース(インボックスに埋もれた課題)。
    func testNeverFocusedWinsOverNoUpdate() throws {
        let reason = StaleEvaluation.reason(status: .inbox,
                                            tier: .someday,
                                            createdAt: day(-30),
                                            focusCount: 0,
                                            practiceCountSinceLeavingFocus: 0,
                                            updatedAt: day(-30),
                                            asOf: asOf)

        XCTAssertEqual(StaleReason.neverFocused, reason)
    }

    func testLeftFocusWinsOverNoUpdate() throws {
        let reason = StaleEvaluation.reason(status: .active,
                                            tier: .next,
                                            createdAt: day(-100),
                                            focusCount: 1,
                                            practiceCountSinceLeavingFocus: 6,
                                            updatedAt: day(-30),
                                            asOf: asOf)

        XCTAssertEqual(StaleReason.leftFocus, reason)
    }

    /// 重点未経験でも、登録が新しければ no_update だけで拾わない。
    func testRecentIssueIsNotStale() throws {
        let reason = StaleEvaluation.reason(status: .inbox,
                                            tier: .someday,
                                            createdAt: day(-1),
                                            focusCount: 0,
                                            practiceCountSinceLeavingFocus: 0,
                                            updatedAt: day(-1),
                                            asOf: asOf)

        XCTAssertNil(reason)
    }

    func testArchivedIsNotStaleEvenWithoutUpdates() throws {
        let reason = StaleEvaluation.reason(status: .archived,
                                            tier: .someday,
                                            createdAt: day(-100),
                                            focusCount: 1,
                                            practiceCountSinceLeavingFocus: 0,
                                            updatedAt: day(-100),
                                            asOf: asOf)

        XCTAssertNil(reason)
    }
}
