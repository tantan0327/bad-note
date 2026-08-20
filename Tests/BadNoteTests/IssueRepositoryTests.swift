import XCTest
import Foundation
import SkipSQL
@testable import BadNote

/// `IssueRepository` の仕様。対象は issue テーブルの CRUD と tier による絞り込みのみ。
///
/// - スキーマは `docs/spec.md` §6 の `issue` テーブル
/// - DB はインメモリ(`SQLContext(configuration: .platform)`)
/// - 時刻は注入したクロックから取る。実時刻に依存させない
final class IssueRepositoryTests: XCTestCase {

    /// 2023-11-14T22:13:20Z。秒未満を持たないので ISO 8601 の往復で誤差が出ない。
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    /// t0 の 1 時間後 = 2023-11-14T23:13:20Z
    private let t1 = Date(timeIntervalSince1970: 1_700_003_600)

    /// テスト中に進めるクロック。`IssueRepository` はここから created_at / updated_at を取る。
    private var clock = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeDatabase() throws -> SQLContext {
        let db = SQLContext(configuration: .platform)
        try AppDatabase.migrate(db)
        return db
    }

    private func makeRepository(_ db: SQLContext) -> IssueRepository {
        clock = t0
        return IssueRepository(db: db, now: { self.clock })
    }

    // MARK: - Create

    func testCreateAssignsIdentifier() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let issue = try repo.create(coachWords: "もっとラケット面、下向いてるよ")

        XCTAssertTrue(issue.id > 0, "採番された id が返ること")
    }

    func testCreateStoresCoachWords() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let issue = try repo.create(coachWords: "もっとラケット面、下向いてるよ")

        XCTAssertEqual("もっとラケット面、下向いてるよ", issue.coachWords)
    }

    /// §3.1 入力時に doneForm を強制しない。未整理の課題は done_form が NULL。
    func testCreateLeavesDoneFormNilWhenOmitted() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let issue = try repo.create(coachWords: "スマッシュのあと戻りが遅い")

        XCTAssertNil(issue.doneForm)
    }

    /// §3.5 種目の既定は `both`、§3.2 習熟度の既定は Lv.1(`solo`)。
    func testCreateDefaultsToBothDisciplineAndSoloLevel() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let issue = try repo.create(coachWords: "スマッシュのあと戻りが遅い")

        XCTAssertEqual(Discipline.both, issue.discipline)
        XCTAssertEqual(MasteryLevel.solo, issue.masteryLevel)
    }

    /// §6 tier の既定は `someday`、status の既定は `inbox`。
    func testCreateDefaultsToSomedayTierAndInboxStatus() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let issue = try repo.create(coachWords: "スマッシュのあと戻りが遅い")

        XCTAssertEqual(Tier.someday, issue.tier)
        XCTAssertEqual(IssueStatus.inbox, issue.status)
    }

    func testCreateDefaultsCountersToZero() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let issue = try repo.create(coachWords: "スマッシュのあと戻りが遅い")

        XCTAssertEqual(0, issue.sortOrder)
        XCTAssertEqual(0, issue.resurfaceCount)
    }

    func testCreateTakesTimestampsFromClock() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let issue = try repo.create(coachWords: "スマッシュのあと戻りが遅い")

        XCTAssertEqual(t0, issue.createdAt)
        XCTAssertEqual(t0, issue.updatedAt)
    }

    /// §4.2 タイムスタンプは UTC の ISO 8601 TEXT で統一して保存する。
    /// 辞書順比較が成立する形であることを、生のカラム値で確認する。
    func testTimestampsAreStoredAsUTCISO8601Text() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let issue = try repo.create(coachWords: "スマッシュのあと戻りが遅い")

        let rows = try db.selectAll(sql: "SELECT created_at FROM issue WHERE id = ?",
                                    parameters: [.long(issue.id)])
        let storedText = try XCTUnwrap(rows.first?.first?.textValue)
        XCTAssertEqual("2023-11-14T22:13:20Z", storedText)
    }

    // MARK: - Read

    func testFetchReturnsEveryStoredAttribute() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let created = try repo.create(coachWords: "もっとラケット面、下向いてるよ",
                                      doneForm: "レシーブでラケット面を立てて構えられている",
                                      coachName: "田中コーチ",
                                      discipline: .doubles,
                                      masteryLevel: .pattern,
                                      tier: .next,
                                      sortOrder: 5,
                                      impact: 3,
                                      cost: 1,
                                      status: .active)

        let fetched = try XCTUnwrap(try repo.fetch(id: created.id))
        XCTAssertEqual(created, fetched, "create の戻り値と fetch の結果が一致すること")
    }

    func testFetchReturnsNilForUnknownIdentifier() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let fetched = try repo.fetch(id: 999)

        XCTAssertNil(fetched)
    }

    func testFetchAllReturnsIssuesFromEveryTier() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        _ = try repo.create(coachWords: "A", tier: .focus)
        _ = try repo.create(coachWords: "B", tier: .next)
        _ = try repo.create(coachWords: "C", tier: .someday)

        let all = try repo.fetchAll()

        XCTAssertEqual(3, all.count)
    }

    func testFetchAllReturnsEmptyArrayWhenNoIssues() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let all = try repo.fetchAll()

        XCTAssertEqual(0, all.count)
    }

    // MARK: - Update

    func testUpdatePersistsChangedFields() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let created = try repo.create(coachWords: "もっとラケット面、下向いてるよ")
        var edited = created
        edited.doneForm = "レシーブでラケット面を立てて構えられている"
        edited.tier = .focus
        edited.masteryLevel = .drill
        edited.impact = 3
        edited.cost = 1
        _ = try repo.update(edited)

        let fetched = try XCTUnwrap(try repo.fetch(id: created.id))
        XCTAssertEqual("レシーブでラケット面を立てて構えられている", fetched.doneForm)
        XCTAssertEqual(Tier.focus, fetched.tier)
        XCTAssertEqual(MasteryLevel.drill, fetched.masteryLevel)
    }

    /// 再浮上・アーカイブで使うライフサイクル列も UPDATE の対象に含める。
    func testUpdatePersistsLifecycleFields() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let created = try repo.create(coachWords: "スマッシュのあと戻りが遅い")
        var edited = created
        edited.status = .archived
        edited.archivedAt = t1
        edited.lastFocusedAt = t1
        edited.resurfaceCount = 2
        _ = try repo.update(edited)

        let fetched = try XCTUnwrap(try repo.fetch(id: created.id))
        XCTAssertEqual(IssueStatus.archived, fetched.status)
        XCTAssertEqual(t1, fetched.archivedAt)
        XCTAssertEqual(t1, fetched.lastFocusedAt)
        XCTAssertEqual(2, fetched.resurfaceCount)
    }

    func testUpdateRefreshesUpdatedAt() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let created = try repo.create(coachWords: "スマッシュのあと戻りが遅い")
        clock = t1
        var edited = created
        edited.tier = .focus
        let updated = try repo.update(edited)

        XCTAssertEqual(t1, updated.updatedAt)
    }

    func testUpdateKeepsCreatedAt() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let created = try repo.create(coachWords: "スマッシュのあと戻りが遅い")
        clock = t1
        var edited = created
        edited.tier = .focus
        let updated = try repo.update(edited)

        XCTAssertEqual(t0, updated.createdAt)
    }

    func testUpdateDoesNotTouchOtherIssues() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let first = try repo.create(coachWords: "A")
        let second = try repo.create(coachWords: "B")
        var edited = first
        edited.coachWords = "A′"
        _ = try repo.update(edited)

        let fetched = try XCTUnwrap(try repo.fetch(id: second.id))
        XCTAssertEqual("B", fetched.coachWords)
    }

    // MARK: - Delete

    func testDeleteRemovesIssue() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let created = try repo.create(coachWords: "スマッシュのあと戻りが遅い")
        try repo.delete(id: created.id)

        let fetched = try repo.fetch(id: created.id)
        XCTAssertNil(fetched)
    }

    func testDeleteLeavesOtherIssues() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let first = try repo.create(coachWords: "A")
        _ = try repo.create(coachWords: "B")
        try repo.delete(id: first.id)

        let all = try repo.fetchAll()
        XCTAssertEqual(1, all.count)
    }

    func testDeleteUnknownIdentifierDoesNotThrow() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        _ = try repo.create(coachWords: "A")
        try repo.delete(id: 999)

        let all = try repo.fetchAll()
        XCTAssertEqual(1, all.count)
    }

    // MARK: - Tier による絞り込み

    func testFetchByTierReturnsOnlyThatTier() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        _ = try repo.create(coachWords: "重点A", tier: .focus)
        _ = try repo.create(coachWords: "重点B", tier: .focus)
        _ = try repo.create(coachWords: "次にやる", tier: .next)
        _ = try repo.create(coachWords: "いつか", tier: .someday)

        let focused = try repo.fetch(tier: .focus)

        XCTAssertEqual(["重点A", "重点B"], focused.map { $0.coachWords })
    }

    func testFetchByTierReturnsEmptyArrayWhenNoneMatch() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        _ = try repo.create(coachWords: "いつか", tier: .someday)

        let focused = try repo.fetch(tier: .focus)

        XCTAssertEqual(0, focused.count)
    }

    /// §3.3 各層の中は手動並び順(`sortOrder`)が既定。
    func testFetchByTierOrdersBySortOrder() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        _ = try repo.create(coachWords: "3番目", tier: .focus, sortOrder: 2)
        _ = try repo.create(coachWords: "1番目", tier: .focus, sortOrder: 0)
        _ = try repo.create(coachWords: "2番目", tier: .focus, sortOrder: 1)

        let focused = try repo.fetch(tier: .focus)

        XCTAssertEqual(["1番目", "2番目", "3番目"], focused.map { $0.coachWords })
    }

    func testFetchByTierReflectsTierChange() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let created = try repo.create(coachWords: "いつか", tier: .someday)
        var edited = created
        edited.tier = .focus
        _ = try repo.update(edited)

        let focused = try repo.fetch(tier: .focus)
        let someday = try repo.fetch(tier: .someday)
        XCTAssertEqual(1, focused.count)
        XCTAssertEqual(0, someday.count)
    }
}
