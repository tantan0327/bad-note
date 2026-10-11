import XCTest
import Foundation
import SkipSQL
@testable import BadNote

/// 見送った課題(`status = shelved`)の扱い(2026-10-11)。
///
/// **定着(`archived`)と混ぜないことが仕様。**
/// 混ぜると、興味を失った課題を外すたびに積み上げの「定着した課題」が増えて、
/// 達成の数字が嘘になる。嘘になるくらいならと外さなくなり、課題が減らなくなる。
final class ShelvedIssueTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000.0)

    private func makeDatabase() throws -> SQLContext {
        let db = SQLContext(configuration: .platform)
        try AppDatabase.prepare(db)
        return db
    }

    private func makeRepository(_ db: SQLContext) -> IssueRepository {
        return IssueRepository(db: db, now: { self.t0 })
    }

    /// 1 件作って指定の状態にする。
    private func makeIssue(_ repository: IssueRepository,
                           words: String,
                           status: IssueStatus) throws -> Issue {
        var issue = try repository.create(coachWords: words)
        issue.status = status
        if status == IssueStatus.archived || status == IssueStatus.shelved {
            issue.archivedAt = t0
        }
        return try repository.update(issue)
    }

    // MARK: - 保存と読み出し

    /// `status` は CHECK の無い TEXT 列なので、値を足すのに移行は要らない。
    /// 保存して読み直せることを直接見る。
    func testShelvedStatusSurvivesARoundTrip() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repository = makeRepository(db)

        let saved = try makeIssue(repository, words: "ハイクリアが浅い", status: IssueStatus.shelved)
        var reloaded: Issue = try XCTUnwrap(try repository.fetch(id: saved.id))

        XCTAssertEqual(IssueStatus.shelved, reloaded.status)
    }

    func testFetchShelvedReturnsOnlyShelved() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repository = makeRepository(db)

        _ = try makeIssue(repository, words: "見送った", status: IssueStatus.shelved)
        _ = try makeIssue(repository, words: "定着した", status: IssueStatus.archived)
        _ = try makeIssue(repository, words: "いま取り組んでいる", status: IssueStatus.active)

        let shelved = try repository.fetchShelved()

        XCTAssertEqual(1, shelved.count)
        XCTAssertEqual("見送った", shelved[0].coachWords)
    }

    func testFetchArchivedDoesNotIncludeShelved() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repository = makeRepository(db)

        _ = try makeIssue(repository, words: "見送った", status: IssueStatus.shelved)

        XCTAssertEqual(0, try repository.fetchArchived().count)
    }

    // MARK: - 積み上げに混ぜない(これがいちばん大事)

    /// 見送っても「定着した課題」の数字は増えない。
    func testShelvingDoesNotCountAsSettled() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repository = makeRepository(db)

        _ = try makeIssue(repository, words: "見送った 1", status: IssueStatus.shelved)
        _ = try makeIssue(repository, words: "見送った 2", status: IssueStatus.shelved)

        XCTAssertEqual(0, try repository.countArchived())
    }

    /// 定着は従来どおり数える(見送りを足したせいで数えなくなっていないこと)。
    func testArchivingStillCountsAsSettled() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repository = makeRepository(db)

        _ = try makeIssue(repository, words: "定着した", status: IssueStatus.archived)
        _ = try makeIssue(repository, words: "見送った", status: IssueStatus.shelved)

        XCTAssertEqual(1, try repository.countArchived())
    }

    /// 積み上げ画面が読む入口(`StatsRepository`)でも同じであること。
    func testStatsDoesNotCountShelvedIssues() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repository = makeRepository(db)

        _ = try makeIssue(repository, words: "見送った", status: IssueStatus.shelved)
        _ = try makeIssue(repository, words: "定着した", status: IssueStatus.archived)

        XCTAssertEqual(1, try StatsRepository(db: db).settledIssueCount())
    }

    // MARK: - 一覧から外れる

    /// 課題一覧は `active` だけを読む。見送った課題は並ばない。
    func testShelvedIssueLeavesTheActiveList() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repository = makeRepository(db)

        _ = try makeIssue(repository, words: "見送った", status: IssueStatus.shelved)
        _ = try makeIssue(repository, words: "いま取り組んでいる", status: IssueStatus.active)

        let active = try repository.fetch(statuses: [IssueStatus.active])

        XCTAssertEqual(1, active.count)
        XCTAssertEqual("いま取り組んでいる", active[0].coachWords)
    }

    /// §4.2 の再浮上の対象は `inbox` と `active` だけ。
    /// **見送った課題が週 1 回また出てくることはない。**
    func testShelvedIssueIsNotAStaleCandidate() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repository = makeRepository(db)

        _ = try makeIssue(repository, words: "見送った", status: IssueStatus.shelved)

        let candidates = try repository.fetch(statuses: [IssueStatus.inbox, IssueStatus.active])

        XCTAssertEqual(0, candidates.count)
    }

    // MARK: - 戻せる

    /// 片道にしない。戻したら `active` に帰り、外した日時は消える。
    func testShelvedIssueCanBeRestored() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repository = makeRepository(db)

        let shelved = try makeIssue(repository, words: "見送った", status: IssueStatus.shelved)
        var edited = shelved
        edited.status = IssueStatus.active
        edited.archivedAt = nil
        _ = try repository.update(edited)

        var restored: Issue = try XCTUnwrap(try repository.fetch(id: shelved.id))

        XCTAssertEqual(IssueStatus.active, restored.status)
        XCTAssertNil(restored.archivedAt)
    }

    // MARK: - 前回の棚卸し

    func testReviewLastDoneAtIsNilUntilRecorded() throws {
        let db = try makeDatabase()
        defer { try? db.close() }

        XCTAssertNil(try AppMetaRepository(db: db).reviewLastDoneAt())
    }

    func testReviewLastDoneAtRoundTrips() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let meta = AppMetaRepository(db: db)

        try meta.setReviewLastDoneAt(t0)

        XCTAssertEqual(t0, try meta.reviewLastDoneAt())
    }
}
