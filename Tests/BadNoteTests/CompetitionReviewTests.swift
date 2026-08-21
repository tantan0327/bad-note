import XCTest
import Foundation
import SkipSQL
@testable import BadNote

/// 大会と課題の紐付け(§6 `issue_competition`)と、大会後の振り返り(§6 `competition_review`)。
final class CompetitionReviewTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    private var clock = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeDatabase() throws -> SQLContext {
        let db = SQLContext(configuration: .platform)
        try AppDatabase.prepare(db)
        return db
    }

    private func makeRepository(_ db: SQLContext) -> CompetitionRepository {
        clock = t0
        return CompetitionRepository(db: db, now: { self.clock })
    }

    private func makeIssues(_ db: SQLContext) -> IssueRepository {
        return IssueRepository(db: db, now: { self.clock })
    }

    // MARK: - 課題との紐付け

    func testSetIssuesLinksThemToCompetition() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)
        let issues = makeIssues(db)

        let competition = try repo.create(name: "県大会", eventDate: t0)
        let first = try issues.create(coachWords: "A")
        let second = try issues.create(coachWords: "B")
        try repo.setIssues([first.id, second.id], for: competition.id)

        XCTAssertEqual(2, try repo.fetchIssueIds(competitionId: competition.id).count)
    }

    func testSetIssuesReplacesPreviousLinks() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)
        let issues = makeIssues(db)

        let competition = try repo.create(name: "県大会", eventDate: t0)
        let first = try issues.create(coachWords: "A")
        let second = try issues.create(coachWords: "B")
        try repo.setIssues([first.id, second.id], for: competition.id)
        try repo.setIssues([first.id], for: competition.id)

        XCTAssertEqual([first.id], try repo.fetchIssueIds(competitionId: competition.id))
    }

    func testSetIssuesIsIdempotent() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)
        let issues = makeIssues(db)

        let competition = try repo.create(name: "県大会", eventDate: t0)
        let issue = try issues.create(coachWords: "A")
        try repo.setIssues([issue.id], for: competition.id)
        try repo.setIssues([issue.id], for: competition.id)

        XCTAssertEqual(1, try repo.fetchIssueIds(competitionId: competition.id).count)
    }

    /// 大会を削除すると紐付けも消える。課題そのものは残る。
    func testDeletingCompetitionRemovesLinksButKeepsIssues() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)
        let issues = makeIssues(db)

        let competition = try repo.create(name: "県大会", eventDate: t0)
        let issue = try issues.create(coachWords: "A")
        try repo.setIssues([issue.id], for: competition.id)
        try repo.delete(id: competition.id)

        let rows = try db.selectAll(sql: "SELECT COUNT(*) FROM issue_competition")
        XCTAssertEqual(Int64(0), try XCTUnwrap(rows.first?.first?.longValue))
        XCTAssertNotNil(try issues.fetch(id: issue.id))
    }

    /// §7.5 この大会までに。**`both` の課題は両方の種目に出す**(§3.5)。
    func testFetchIssuesForCompetitionByDiscipline() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)
        let issues = makeIssues(db)

        let competition = try repo.create(name: "県大会", eventDate: t0)
        let singles = try issues.create(coachWords: "シングルス専用", discipline: .singles)
        let both = try issues.create(coachWords: "両方", discipline: .both)
        let unlinked = try issues.create(coachWords: "紐付けなし", discipline: .singles)
        try repo.setIssues([singles.id, both.id], for: competition.id)

        let found = try issues.fetch(competitionId: competition.id, discipline: .singles)

        XCTAssertEqual(["シングルス専用", "両方"], found.map { $0.coachWords })
        XCTAssertNotNil(unlinked)
    }

    // MARK: - 振り返り(種目ごとに 1 セット)

    func testSaveAndFetchReview() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let competition = try repo.create(name: "県大会", eventDate: t0)
        try repo.saveReview(competitionId: competition.id,
                            discipline: .singles,
                            result: "ベスト8",
                            wentWell: "レシーブが安定した",
                            nextAction: "スマッシュのあと戻りを速くする",
                            neededResources: "ノックを出してくれる人")

        let review = try XCTUnwrap(try repo.fetchReview(competitionId: competition.id, discipline: .singles))
        XCTAssertEqual("ベスト8", review.result)
        XCTAssertEqual("スマッシュのあと戻りを速くする", review.nextAction)
    }

    /// §6 UNIQUE (competition_id, discipline)。保存し直しても 1 件のまま。
    func testSavingReviewTwiceKeepsOneRow() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let competition = try repo.create(name: "県大会", eventDate: t0)
        try repo.saveReview(competitionId: competition.id, discipline: .singles, result: "1回戦敗退")
        try repo.saveReview(competitionId: competition.id, discipline: .singles, result: "ベスト8")

        let rows = try db.selectAll(sql: "SELECT COUNT(*) FROM competition_review")
        XCTAssertEqual(Int64(1), try XCTUnwrap(rows.first?.first?.longValue))
        let review = try XCTUnwrap(try repo.fetchReview(competitionId: competition.id, discipline: .singles))
        XCTAssertEqual("ベスト8", review.result)
    }

    /// 種目ごとに 1 セット。シングルスとダブルスは別の記録。
    func testReviewsAreSeparatePerDiscipline() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let competition = try repo.create(name: "県大会", eventDate: t0)
        try repo.saveReview(competitionId: competition.id, discipline: .singles, result: "ベスト8")
        try repo.saveReview(competitionId: competition.id, discipline: .doubles, result: "優勝")

        let singles = try XCTUnwrap(try repo.fetchReview(competitionId: competition.id, discipline: .singles))
        let doubles = try XCTUnwrap(try repo.fetchReview(competitionId: competition.id, discipline: .doubles))
        XCTAssertEqual("ベスト8", singles.result)
        XCTAssertEqual("優勝", doubles.result)
    }

    func testFetchReviewReturnsNilWhenNotWritten() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let competition = try repo.create(name: "県大会", eventDate: t0)

        XCTAssertNil(try repo.fetchReview(competitionId: competition.id, discipline: .singles))
    }

    /// 全項目任意。空のまま保存できる。
    func testReviewFieldsAreOptional() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let competition = try repo.create(name: "県大会", eventDate: t0)
        try repo.saveReview(competitionId: competition.id, discipline: .singles)

        let review = try XCTUnwrap(try repo.fetchReview(competitionId: competition.id, discipline: .singles))
        XCTAssertNil(review.result)
        XCTAssertNil(review.wentWell)
    }

    func testDeletingCompetitionRemovesReviews() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let competition = try repo.create(name: "県大会", eventDate: t0)
        try repo.saveReview(competitionId: competition.id, discipline: .singles, result: "ベスト8")
        try repo.delete(id: competition.id)

        let rows = try db.selectAll(sql: "SELECT COUNT(*) FROM competition_review")
        XCTAssertEqual(Int64(0), try XCTUnwrap(rows.first?.first?.longValue))
    }
}
