import XCTest
import Foundation
import SkipSQL
@testable import BadNote

/// 習熟度の変更履歴(§6 `level_change`)。
///
/// §7.3 の「レベルアップ回数」と §5.1 の積み上げ表示の元になる。
/// 履歴は `IssueRepository.update(_:)` が自動で残す —— 呼び出し側が書き忘れられない形にする。
final class LevelChangeTests: XCTestCase {

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

    // MARK: - 記録される場合

    func testUpdateRecordsLevelChange() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let created = try repo.create(coachWords: "A")
        var edited = created
        edited.masteryLevel = .drill
        _ = try repo.update(edited)

        let changes = try repo.fetchLevelChanges(issueId: created.id)
        XCTAssertEqual(1, changes.count)
    }

    func testLevelChangeKeepsFromAndToLevels() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let created = try repo.create(coachWords: "A")
        var edited = created
        edited.masteryLevel = .pattern
        _ = try repo.update(edited)

        let change = try XCTUnwrap(try repo.fetchLevelChanges(issueId: created.id).first)
        XCTAssertEqual(MasteryLevel.solo, change.fromLevel)
        XCTAssertEqual(MasteryLevel.pattern, change.toLevel)
    }

    func testLevelChangeTakesCreatedAtFromClock() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let created = try repo.create(coachWords: "A")
        clock = t1
        var edited = created
        edited.masteryLevel = .drill
        _ = try repo.update(edited)

        let change = try XCTUnwrap(try repo.fetchLevelChanges(issueId: created.id).first)
        XCTAssertEqual(t1, change.createdAt)
    }

    /// §3.2 レベルを下げる操作も履歴に残す。
    func testLevelDownIsRecorded() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let created = try repo.create(coachWords: "A", masteryLevel: .match)
        var edited = created
        edited.masteryLevel = .pattern
        _ = try repo.update(edited)

        let change = try XCTUnwrap(try repo.fetchLevelChanges(issueId: created.id).first)
        XCTAssertFalse(change.isLevelUp)
    }

    func testLevelUpIsMarkedAsLevelUp() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let created = try repo.create(coachWords: "A")
        var edited = created
        edited.masteryLevel = .drill
        _ = try repo.update(edited)

        let change = try XCTUnwrap(try repo.fetchLevelChanges(issueId: created.id).first)
        XCTAssertTrue(change.isLevelUp)
    }

    /// 何度も変えれば、その分だけ古い順に積み上がる。
    func testChangesAreReturnedOldestFirst() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let created = try repo.create(coachWords: "A")
        var edited = created
        edited.masteryLevel = .drill
        let afterFirst = try repo.update(edited)
        clock = t1
        var again = afterFirst
        again.masteryLevel = .pattern
        _ = try repo.update(again)

        let changes = try repo.fetchLevelChanges(issueId: created.id)
        XCTAssertEqual([MasteryLevel.drill, MasteryLevel.pattern], changes.map { $0.toLevel })
    }

    // MARK: - 記録されない場合

    /// 新規登録は「変更」ではない。
    func testCreateDoesNotRecordLevelChange() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let created = try repo.create(coachWords: "A", masteryLevel: .drill)

        let changes = try repo.fetchLevelChanges(issueId: created.id)
        XCTAssertEqual(0, changes.count)
    }

    /// レベル以外を変えただけの保存では履歴を作らない。
    /// 層の入れ替えのたびに履歴が増えると「レベルアップ回数」が嘘になる。
    func testUpdateWithoutLevelChangeRecordsNothing() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let created = try repo.create(coachWords: "A")
        var edited = created
        edited.tier = .focus
        edited.doneForm = "できている"
        _ = try repo.update(edited)

        let changes = try repo.fetchLevelChanges(issueId: created.id)
        XCTAssertEqual(0, changes.count)
    }

    func testFetchLevelChangesIsEmptyForUntouchedIssue() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let created = try repo.create(coachWords: "A")

        XCTAssertEqual(0, try repo.fetchLevelChanges(issueId: created.id).count)
    }

    func testFetchLevelChangesExcludesOtherIssues() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let first = try repo.create(coachWords: "A")
        let second = try repo.create(coachWords: "B")
        var edited = second
        edited.masteryLevel = .drill
        _ = try repo.update(edited)

        XCTAssertEqual(0, try repo.fetchLevelChanges(issueId: first.id).count)
    }

    // MARK: - カスケード

    /// 課題を削除すると履歴も消える(ON DELETE CASCADE)。
    func testDeletingIssueRemovesLevelChanges() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let created = try repo.create(coachWords: "A")
        var edited = created
        edited.masteryLevel = .drill
        _ = try repo.update(edited)
        try repo.delete(id: created.id)

        let rows = try db.selectAll(sql: "SELECT COUNT(*) FROM level_change")
        let remaining = try XCTUnwrap(rows.first?.first?.longValue)
        XCTAssertEqual(Int64(0), remaining)
    }

    // MARK: - 期間のレベルアップ回数(§5.1)

    func testCountLevelUpsInRange() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let first = try repo.create(coachWords: "A")
        let second = try repo.create(coachWords: "B")
        var editedFirst = first
        editedFirst.masteryLevel = .drill
        _ = try repo.update(editedFirst)
        var editedSecond = second
        editedSecond.masteryLevel = .drill
        _ = try repo.update(editedSecond)

        let count = try repo.countLevelUps(from: t0, to: t1)

        XCTAssertEqual(2, count)
    }

    /// 下げた記録は「レベルアップ回数」に数えない。
    func testCountLevelUpsExcludesLevelDowns() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let created = try repo.create(coachWords: "A", masteryLevel: .match)
        var edited = created
        edited.masteryLevel = .drill
        _ = try repo.update(edited)

        let count = try repo.countLevelUps(from: t0, to: t1)

        XCTAssertEqual(0, count)
    }

    /// 境界: 終了時刻ちょうどは含まない(翌月の頭をそのまま渡せる形)。
    func testCountLevelUpsExcludesEnd() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let created = try repo.create(coachWords: "A")
        clock = t1
        var edited = created
        edited.masteryLevel = .drill
        _ = try repo.update(edited)

        let count = try repo.countLevelUps(from: t0, to: t1)

        XCTAssertEqual(0, count)
    }

    func testCountLevelUpsIsZeroWithoutChanges() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        _ = try repo.create(coachWords: "A")

        XCTAssertEqual(0, try repo.countLevelUps(from: t0, to: t1))
    }
}
