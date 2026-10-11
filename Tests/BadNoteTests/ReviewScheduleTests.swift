import XCTest
import Foundation
@testable import BadNote

/// 棚卸しをいつ誘うか、何件見るか(2026-10-11)。
///
/// **誘いすぎないことが仕様。** 毎日出れば無視されるようになり、
/// 溜まっていないのに出れば邪魔なだけになる。
final class ReviewScheduleTests: XCTestCase {

    /// 2023-11-14T22:13:20Z
    private let today = Date(timeIntervalSince1970: 1_700_000_000.0)

    private func daysBefore(_ days: Double) -> Date {
        return Date(timeIntervalSince1970: today.timeIntervalSince1970 - days * 86_400.0)
    }

    private func issue(id: Int64, createdDaysAgo: Double = 0.0, focusedDaysAgo: Double? = nil) -> Issue {
        var focusedAt: Date? = nil
        if let focusedDaysAgo = focusedDaysAgo {
            focusedAt = daysBefore(focusedDaysAgo)
        }
        return Issue(id: id,
                     coachWords: "課題 \(id)",
                     masteryLevel: MasteryLevel.solo,
                     tier: Tier.someday,
                     status: IssueStatus.active,
                     lastFocusedAt: focusedAt,
                     createdAt: daysBefore(createdDaysAgo),
                     updatedAt: today)
    }

    private func issues(count: Int) -> [Issue] {
        var result: [Issue] = []
        var index = 1
        while index <= count {
            result.append(issue(id: Int64(index)))
            index += 1
        }
        return result
    }

    private func ids(_ issues: [Issue]) -> [Int64] {
        var result: [Int64] = []
        for issue in issues {
            result.append(issue.id)
        }
        return result
    }

    // MARK: - 件数が先

    /// **溜まっていなければ誘わない。** 6 件の「いつか」に棚卸しは要らない。
    func testDoesNotInviteWhenBacklogIsSmall() {
        XCTAssertFalse(ReviewSchedule.isDue(today: today, lastReviewedAt: nil, backlogCount: 9))
    }

    func testInvitesAtTheThreshold() {
        XCTAssertTrue(ReviewSchedule.isDue(today: today, lastReviewedAt: nil, backlogCount: 10))
    }

    /// 前回から十分経っていても、減っていれば誘わない。
    func testDoesNotInviteWhenBacklogShrankBelowThreshold() {
        XCTAssertFalse(ReviewSchedule.isDue(today: today,
                                            lastReviewedAt: daysBefore(200.0),
                                            backlogCount: 3))
    }

    // MARK: - 間隔

    func testInvitesWhenNeverReviewed() {
        XCTAssertTrue(ReviewSchedule.isDue(today: today, lastReviewedAt: nil, backlogCount: 30))
    }

    /// **起動のたびに誘わない。** 今日すでに済ませていれば出さない。
    func testDoesNotInviteTwiceOnTheSameDay() {
        XCTAssertFalse(ReviewSchedule.isDue(today: today,
                                            lastReviewedAt: today,
                                            backlogCount: 30))
    }

    func testDoesNotInviteBeforeTheInterval() {
        XCTAssertFalse(ReviewSchedule.isDue(today: today,
                                            lastReviewedAt: daysBefore(29.0),
                                            backlogCount: 30))
    }

    func testInvitesAfterTheInterval() {
        XCTAssertTrue(ReviewSchedule.isDue(today: today,
                                           lastReviewedAt: daysBefore(30.0),
                                           backlogCount: 30))
    }

    /// 週 1 回の stale(`StaleSchedule`)より十分に長い。重ねて急かさない。
    func testIntervalIsAMonth() {
        XCTAssertEqual(30, ReviewSchedule.intervalDays)
        XCTAssertTrue(ReviewSchedule.intervalDays > StaleSchedule.rescueDays)
    }

    // MARK: - 1 回分の並び

    /// **放置が長い順。** いちばん忘れているものから聞く。
    func testQueueTakesTheLongestUntouchedFirst() {
        let given = [issue(id: 1, focusedDaysAgo: 5.0),
                     issue(id: 2, focusedDaysAgo: 100.0),
                     issue(id: 3, focusedDaysAgo: 40.0)]

        XCTAssertEqual([Int64(2), Int64(3), Int64(1)], ids(ReviewSchedule.queue(from: given)))
    }

    /// **終わらない棚卸しは二度とやられない。** 1 回で見るのは上限まで。
    func testQueueStopsAtTheSessionLimit() {
        let queue = ReviewSchedule.queue(from: issues(count: 40))

        XCTAssertEqual(ReviewSchedule.sessionLimit, queue.count)
        XCTAssertEqual(10, queue.count)
    }

    func testQueueKeepsEverythingWhenUnderTheLimit() {
        let queue = ReviewSchedule.queue(from: issues(count: 4))

        XCTAssertEqual(4, queue.count)
    }

    func testQueueOfNothingIsEmpty() {
        XCTAssertEqual([Int64](), ids(ReviewSchedule.queue(from: [Issue]())))
    }
}
