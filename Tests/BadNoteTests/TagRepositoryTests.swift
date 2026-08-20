import XCTest
import Foundation
import SkipSQL
@testable import BadNote

/// `TagRepository` の仕様。対象は `tag` と `issue_tag`(§6)。
///
/// - タグ名は UNIQUE。同名は作り直さず既存を返す
/// - 課題への付け外しは `issue_tag` の 1 行の出し入れ
/// - DB はテストごとに新規のインメモリ(`SQLContext(configuration: .platform)`)
final class TagRepositoryTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeDatabase() throws -> SQLContext {
        let db = SQLContext(configuration: .platform)
        try AppDatabase.prepare(db)
        return db
    }

    private func makeRepository(_ db: SQLContext) -> TagRepository {
        return TagRepository(db: db)
    }

    private func makeIssueRepository(_ db: SQLContext) -> IssueRepository {
        return IssueRepository(db: db, now: { self.t0 })
    }

    private func issueTagCount(_ db: SQLContext) throws -> Int64 {
        let rows = try db.selectAll(sql: "SELECT COUNT(*) FROM issue_tag")
        return try XCTUnwrap(rows.first?.first?.longValue)
    }

    // MARK: - タグの作成

    func testCreateAssignsIdentifier() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let tag = try repo.create(name: "スマッシュ")

        XCTAssertTrue(tag.id > 0)
    }

    func testCreateStoresName() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let tag = try repo.create(name: "スマッシュ")

        XCTAssertEqual("スマッシュ", tag.name)
    }

    /// §6 tag.name は UNIQUE。同名なら既存のタグを返す。
    func testCreateReturnsExistingTagForSameName() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let first = try repo.create(name: "スマッシュ")
        let second = try repo.create(name: "スマッシュ")

        XCTAssertEqual(first.id, second.id)
    }

    func testCreateDoesNotDuplicateRowsForSameName() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        _ = try repo.create(name: "スマッシュ")
        _ = try repo.create(name: "スマッシュ")

        let tags = try repo.fetchAll()
        XCTAssertEqual(1, tags.count)
    }

    /// 前後の空白違いで別タグにしない。
    func testCreateTrimsSurroundingWhitespace() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let first = try repo.create(name: "スマッシュ")
        let second = try repo.create(name: "  スマッシュ  ")

        XCTAssertEqual(first.id, second.id)
    }

    func testCreateStoresTrimmedName() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let tag = try repo.create(name: "  スマッシュ  ")

        XCTAssertEqual("スマッシュ", tag.name)
    }

    func testCreateRejectsBlankName() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        var threw = false
        do {
            _ = try repo.create(name: "   ")
        } catch {
            threw = true
        }

        XCTAssertTrue(threw)
    }

    /// 別の名前は別のタグ。
    func testCreateMakesSeparateTagsForDifferentNames() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let smash = try repo.create(name: "スマッシュ")
        let clear = try repo.create(name: "クリア")

        XCTAssertNotEqual(smash.id, clear.id)
    }

    // MARK: - タグの取得

    func testFetchByNameReturnsTag() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let created = try repo.create(name: "スマッシュ")

        let fetched = try repo.fetch(name: "スマッシュ")

        XCTAssertEqual(created, fetched)
    }

    func testFetchByNameReturnsNilWhenMissing() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let fetched = try repo.fetch(name: "スマッシュ")

        XCTAssertNil(fetched)
    }

    func testFetchAllOrdersByName() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        _ = try repo.create(name: "ロブ")
        _ = try repo.create(name: "クリア")
        _ = try repo.create(name: "スマッシュ")

        let tags = try repo.fetchAll()

        XCTAssertEqual(["クリア", "スマッシュ", "ロブ"], tags.map { $0.name })
    }

    func testFetchAllReturnsEmptyArrayWhenNoTags() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let tags = try repo.fetchAll()

        XCTAssertEqual(0, tags.count)
    }

    // MARK: - 課題への付け外し

    func testAttachAddsTagToIssue() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)
        let issues = makeIssueRepository(db)

        let issue = try issues.create(coachWords: "スマッシュのあと戻りが遅い")
        let tag = try repo.create(name: "スマッシュ")
        try repo.attach(tagId: tag.id, to: issue.id)

        let tags = try repo.fetchTags(issueId: issue.id)
        XCTAssertEqual([tag], tags)
    }

    /// 同じタグを 2 回付けても 1 行。§6 PRIMARY KEY (issue_id, tag_id)。
    func testAttachIsIdempotent() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)
        let issues = makeIssueRepository(db)

        let issue = try issues.create(coachWords: "A")
        let tag = try repo.create(name: "スマッシュ")
        try repo.attach(tagId: tag.id, to: issue.id)
        try repo.attach(tagId: tag.id, to: issue.id)

        XCTAssertEqual(Int64(1), try issueTagCount(db))
    }

    func testAttachRejectsUnknownIssue() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let tag = try repo.create(name: "スマッシュ")
        var threw = false
        do {
            try repo.attach(tagId: tag.id, to: 999)
        } catch {
            threw = true
        }

        XCTAssertTrue(threw, "存在しない課題への付与は外部キー制約で失敗すること")
    }

    func testDetachRemovesTagFromIssue() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)
        let issues = makeIssueRepository(db)

        let issue = try issues.create(coachWords: "A")
        let tag = try repo.create(name: "スマッシュ")
        try repo.attach(tagId: tag.id, to: issue.id)
        try repo.detach(tagId: tag.id, from: issue.id)

        let tags = try repo.fetchTags(issueId: issue.id)
        XCTAssertEqual(0, tags.count)
    }

    func testDetachLeavesOtherTags() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)
        let issues = makeIssueRepository(db)

        let issue = try issues.create(coachWords: "A")
        let smash = try repo.create(name: "スマッシュ")
        let clear = try repo.create(name: "クリア")
        try repo.attach(tagId: smash.id, to: issue.id)
        try repo.attach(tagId: clear.id, to: issue.id)
        try repo.detach(tagId: smash.id, from: issue.id)

        let tags = try repo.fetchTags(issueId: issue.id)
        XCTAssertEqual([clear], tags)
    }

    func testDetachUnknownPairDoesNothing() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)
        let issues = makeIssueRepository(db)

        let issue = try issues.create(coachWords: "A")
        let tag = try repo.create(name: "スマッシュ")
        try repo.detach(tagId: tag.id, from: issue.id)

        XCTAssertEqual(Int64(0), try issueTagCount(db))
    }

    func testFetchTagsReturnsTagsOfThatIssueOnly() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)
        let issues = makeIssueRepository(db)

        let first = try issues.create(coachWords: "A")
        let second = try issues.create(coachWords: "B")
        let smash = try repo.create(name: "スマッシュ")
        let clear = try repo.create(name: "クリア")
        try repo.attach(tagId: smash.id, to: first.id)
        try repo.attach(tagId: clear.id, to: second.id)

        let tags = try repo.fetchTags(issueId: first.id)

        XCTAssertEqual([smash], tags)
    }

    func testFetchTagsOrdersByName() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)
        let issues = makeIssueRepository(db)

        let issue = try issues.create(coachWords: "A")
        let lob = try repo.create(name: "ロブ")
        let clear = try repo.create(name: "クリア")
        try repo.attach(tagId: lob.id, to: issue.id)
        try repo.attach(tagId: clear.id, to: issue.id)

        let tags = try repo.fetchTags(issueId: issue.id)

        XCTAssertEqual(["クリア", "ロブ"], tags.map { $0.name })
    }

    func testFetchTagsReturnsEmptyArrayForUntaggedIssue() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)
        let issues = makeIssueRepository(db)

        let issue = try issues.create(coachWords: "A")

        let tags = try repo.fetchTags(issueId: issue.id)

        XCTAssertEqual(0, tags.count)
    }

    // MARK: - カスケード

    /// 課題を削除すると issue_tag も消える(ON DELETE CASCADE)。
    func testDeletingIssueRemovesIssueTagRows() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)
        let issues = makeIssueRepository(db)

        let issue = try issues.create(coachWords: "A")
        let smash = try repo.create(name: "スマッシュ")
        let clear = try repo.create(name: "クリア")
        try repo.attach(tagId: smash.id, to: issue.id)
        try repo.attach(tagId: clear.id, to: issue.id)
        try issues.delete(id: issue.id)

        XCTAssertEqual(Int64(0), try issueTagCount(db))
    }

    /// 消えるのは紐付けだけ。タグそのものは他の課題でも使うので残す。
    func testDeletingIssueKeepsTag() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)
        let issues = makeIssueRepository(db)

        let issue = try issues.create(coachWords: "A")
        let tag = try repo.create(name: "スマッシュ")
        try repo.attach(tagId: tag.id, to: issue.id)
        try issues.delete(id: issue.id)

        let tags = try repo.fetchAll()
        XCTAssertEqual([tag], tags)
    }

    func testDeletingTagRemovesIssueTagRows() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)
        let issues = makeIssueRepository(db)

        let issue = try issues.create(coachWords: "A")
        let tag = try repo.create(name: "スマッシュ")
        try repo.attach(tagId: tag.id, to: issue.id)
        try repo.delete(id: tag.id)

        XCTAssertEqual(Int64(0), try issueTagCount(db))
    }

    func testDeletingTagKeepsIssue() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)
        let issues = makeIssueRepository(db)

        let issue = try issues.create(coachWords: "A")
        let tag = try repo.create(name: "スマッシュ")
        try repo.attach(tagId: tag.id, to: issue.id)
        try repo.delete(id: tag.id)

        let fetched = try issues.fetch(id: issue.id)
        XCTAssertNotNil(fetched)
    }
}
