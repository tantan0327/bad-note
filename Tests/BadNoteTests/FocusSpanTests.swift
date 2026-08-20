import XCTest
import Foundation
import SkipSQL
@testable import BadNote

/// focus 在籍履歴(§6 `focus_span`)。
///
/// stale の条件と §7.3「重点にした回数」を賄う。
/// 記録は `IssueRepository` が自動で行う —— 経路が増えても書き忘れない形にする。
final class FocusSpanTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    private let t1 = Date(timeIntervalSince1970: 1_700_003_600)

    private var clock = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeDatabase() throws -> SQLContext {
        let db = SQLContext(configuration: .platform)
        try AppDatabase.prepare(db)
        return db
    }

    private func makeRepository(_ db: SQLContext) -> IssueRepository {
        clock = t0
        return IssueRepository(db: db, now: { self.clock })
    }

    // MARK: - 重点に入れる

    func testMovingIntoFocusOpensSpan() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let created = try repo.create(coachWords: "A")
        var edited = created
        edited.tier = .focus
        _ = try repo.update(edited)

        XCTAssertEqual(1, try repo.focusSpanCount(issueId: created.id))
    }

    func testCreatingDirectlyInFocusOpensSpan() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let created = try repo.create(coachWords: "A", tier: .focus)

        XCTAssertEqual(1, try repo.focusSpanCount(issueId: created.id))
    }

    /// §4.3 重点にする時に last_focused_at を更新する。
    func testMovingIntoFocusUpdatesLastFocusedAt() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let created = try repo.create(coachWords: "A")
        clock = t1
        var edited = created
        edited.tier = .focus
        let updated = try repo.update(edited)

        XCTAssertEqual(t1, updated.lastFocusedAt)
    }

    /// 重点の中で並び替えただけでは増えない。
    func testReorderingWithinFocusDoesNotOpenAnotherSpan() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let created = try repo.create(coachWords: "A", tier: .focus)
        var edited = created
        edited.sortOrder = 2
        _ = try repo.update(edited)

        XCTAssertEqual(1, try repo.focusSpanCount(issueId: created.id))
    }

    // MARK: - 重点から外す

    func testLeavingFocusClosesSpan() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let created = try repo.create(coachWords: "A", tier: .focus)
        clock = t1
        var edited = created
        edited.tier = .next
        _ = try repo.update(edited)

        XCTAssertEqual(t1, try repo.lastLeftFocusAt(issueId: created.id))
    }

    /// 重点にいる間は「外れた日時」が無い。
    func testOpenSpanHasNoLeftAt() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let created = try repo.create(coachWords: "A", tier: .focus)

        XCTAssertNil(try repo.lastLeftFocusAt(issueId: created.id))
    }

    /// 出入りを繰り返せば、その回数だけ積み上がる(§7.3 重点にした回数)。
    func testReenteringFocusOpensSecondSpan() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let created = try repo.create(coachWords: "A", tier: .focus)
        var out = created
        out.tier = .next
        let afterLeaving = try repo.update(out)
        var back = afterLeaving
        back.tier = .focus
        _ = try repo.update(back)

        XCTAssertEqual(2, try repo.focusSpanCount(issueId: created.id))
    }

    func testFocusSpanCountIsZeroForNeverFocusedIssue() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let created = try repo.create(coachWords: "A")

        XCTAssertEqual(0, try repo.focusSpanCount(issueId: created.id))
    }

    /// 課題を削除すると在籍履歴も消える。
    func testDeletingIssueRemovesSpans() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let created = try repo.create(coachWords: "A", tier: .focus)
        try repo.delete(id: created.id)

        let rows = try db.selectAll(sql: "SELECT COUNT(*) FROM focus_span")
        XCTAssertEqual(Int64(0), try XCTUnwrap(rows.first?.first?.longValue))
    }

    // MARK: - 外れてからの練習回数(§4.2 left_focus)

    func testCountsPracticesAfterLeavingFocus() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)
        let practices = PracticeRepository(db: db, now: { self.clock })

        _ = try practices.create(practiceDate: t0, minutes: 60)
        let count = try practices.countPractices(after: t0)

        XCTAssertEqual(0, count, "外れた時刻と同時の練習は含めない")
    }

    func testCountsOnlyPracticesAfterGivenDate() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)
        let practices = PracticeRepository(db: db, now: { self.clock })

        _ = try practices.create(practiceDate: t0, minutes: 60)
        _ = try practices.create(practiceDate: t1, minutes: 60)

        XCTAssertEqual(1, try practices.countPractices(after: t0))
    }
}
