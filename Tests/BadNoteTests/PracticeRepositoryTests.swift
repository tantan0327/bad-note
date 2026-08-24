import XCTest
import Foundation
import SkipSQL
@testable import BadNote

/// `PracticeRepository` の仕様。対象は `practice` と `focus_record` の 2 テーブル。
///
/// - スキーマは `docs/spec.md` §6
/// - DB はテストごとに新規のインメモリ(`SQLContext(configuration: .platform)`)
/// - 時刻は注入したクロックから取る。実時刻に依存させない
/// 呼び出し側トランザクションのロールバック確認用(6.3)。
private struct AbortForTest: Error {
}

final class PracticeRepositoryTests: XCTestCase {

    /// 練習ログと課題の書き込みを 1 つのトランザクションに畳める(6.3)。
    /// 途中で失敗したら両方とも巻き戻る —— 片方だけ残さない。
    func testCreateInCurrentTransactionRollsBackWithCaller() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let practices = makePracticeRepository(db)
        let issues = makeIssueRepository(db)

        // XCTAssertThrowsError は Skip 非対応(開発メモ)なので do/catch で確かめる
        var didThrow = false
        do {
            try db.transaction {
                _ = try practices.createInCurrentTransaction(practiceDate: t0, minutes: 60)
                _ = try issues.create(coachWords: "ラケット面が下向き")
                throw AbortForTest()
            }
        } catch {
            didThrow = true
        }
        XCTAssertTrue(didThrow)

        XCTAssertEqual(0, try practices.count())
        XCTAssertEqual(0, try issues.fetch(statuses: [.inbox]).count)
    }

    /// 成功すれば両方とも残る(6.3 の畳み込みが普段の保存を壊さないこと)。
    func testCreateInCurrentTransactionCommitsWithCaller() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let practices = makePracticeRepository(db)
        let issues = makeIssueRepository(db)

        _ = try db.transaction {
            let created = try practices.createInCurrentTransaction(practiceDate: t0, minutes: 60)
            _ = try issues.create(coachWords: "ラケット面が下向き")
            return created
        }

        XCTAssertEqual(1, try practices.count())
        XCTAssertEqual(1, try issues.fetch(statuses: [.inbox]).count)
    }

    /// 2023-11-14T22:13:20Z
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    /// t0 の 1 時間後 = 2023-11-14T23:13:20Z
    private let t1 = Date(timeIntervalSince1970: 1_700_003_600)

    private var clock = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeDatabase() throws -> SQLContext {
        let db = SQLContext(configuration: .platform)
        try AppDatabase.prepare(db)
        return db
    }

    private func makePracticeRepository(_ db: SQLContext) -> PracticeRepository {
        clock = t0
        return PracticeRepository(db: db, now: { self.clock })
    }

    private func makeIssueRepository(_ db: SQLContext) -> IssueRepository {
        return IssueRepository(db: db, now: { self.clock })
    }

    // MARK: - 外部キー制約

    /// SQLite の外部キーは接続ごとに既定で OFF。ON になっていないと
    /// ON DELETE CASCADE も参照チェックも効かない。
    func testForeignKeysAreEnabled() throws {
        let db = try makeDatabase()
        defer { try? db.close() }

        let rows = try db.selectAll(sql: "PRAGMA foreign_keys")
        let enabled = try XCTUnwrap(rows.first?.first?.longValue)

        XCTAssertEqual(Int64(1), enabled)
    }

    // MARK: - Create

    func testCreateAssignsIdentifier() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makePracticeRepository(db)

        let practice = try repo.create(practiceDate: t0, minutes: 90, kind: .whole)

        XCTAssertTrue(practice.id > 0)
    }

    func testCreateStoresPracticeAttributes() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makePracticeRepository(db)

        let created = try repo.create(practiceDate: t0, minutes: 90, kind: .game)

        let fetched = try XCTUnwrap(try repo.fetch(id: created.id))
        XCTAssertEqual(created, fetched, "create の戻り値と fetch の結果が一致すること")
    }

    /// §7.2 全項目任意。時間も種類も未入力で保存できる。
    func testCreateDefaultsMinutesToZeroAndKindToNil() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makePracticeRepository(db)

        let practice = try repo.create(practiceDate: t0)

        XCTAssertEqual(0, practice.minutes)
        XCTAssertNil(practice.kind)
    }

    func testCreateTakesCreatedAtFromClock() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makePracticeRepository(db)

        let practice = try repo.create(practiceDate: t1)

        XCTAssertEqual(t0, practice.createdAt, "created_at はクロックの現在時刻")
        XCTAssertEqual(t1, practice.practiceDate, "practice_date は渡された日付")
    }

    /// §4.2 タイムスタンプは UTC の ISO 8601 TEXT で統一する。
    /// `practice_date > left_at` の比較がずれないこと。
    func testPracticeDateIsStoredAsUTCISO8601Text() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makePracticeRepository(db)

        let practice = try repo.create(practiceDate: t0)

        let rows = try db.selectAll(sql: "SELECT practice_date FROM practice WHERE id = ?",
                                    parameters: [.long(practice.id)])
        let storedText = try XCTUnwrap(rows.first?.first?.textValue)
        XCTAssertEqual("2023-11-14T22:13:20Z", storedText)
    }

    // MARK: - 手応え(focus_record)

    func testCreateStoresFocusRecords() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makePracticeRepository(db)
        let issues = makeIssueRepository(db)

        let issueA = try issues.create(coachWords: "A")
        let issueB = try issues.create(coachWords: "B")
        let practice = try repo.create(practiceDate: t0, minutes: 90, focus: [
            FocusEntry(issueId: issueA.id, result: .done),
            FocusEntry(issueId: issueB.id, result: .closer),
        ])

        let records = try repo.fetchFocusRecords(practiceId: practice.id)

        XCTAssertEqual(2, records.count)
    }

    func testCreateStoresFocusResult() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makePracticeRepository(db)
        let issues = makeIssueRepository(db)

        let issue = try issues.create(coachWords: "A")
        let practice = try repo.create(practiceDate: t0, focus: [
            FocusEntry(issueId: issue.id, result: .done),
        ])

        let records = try repo.fetchFocusRecords(practiceId: practice.id)
        let record = try XCTUnwrap(records.first)
        XCTAssertEqual(FocusResult.done, record.result)
    }

    /// §7.2 手応え未選択でも保存できる。未入力は異常ではなく正常な状態。
    func testCreateAllowsNilResult() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makePracticeRepository(db)
        let issues = makeIssueRepository(db)

        let issue = try issues.create(coachWords: "A")
        let practice = try repo.create(practiceDate: t0, focus: [
            FocusEntry(issueId: issue.id, result: nil),
        ])

        let records = try repo.fetchFocusRecords(practiceId: practice.id)
        let record = try XCTUnwrap(records.first)
        XCTAssertNil(record.result)
    }

    /// 未入力は空文字や 'none' ではなく SQL の NULL で保存する。
    func testNilResultIsStoredAsNullColumn() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makePracticeRepository(db)
        let issues = makeIssueRepository(db)

        let issue = try issues.create(coachWords: "A")
        let practice = try repo.create(practiceDate: t0, focus: [
            FocusEntry(issueId: issue.id, result: nil),
        ])

        let rows = try db.selectAll(sql: "SELECT result FROM focus_record WHERE practice_id = ?",
                                    parameters: [.long(practice.id)])
        let stored = try XCTUnwrap(rows.first?.first)
        XCTAssertEqual(SQLValue.null, stored)
    }

    // MARK: - トランザクション

    /// 練習ログと手応えは 1 トランザクション。手応えの保存が失敗したら
    /// practice 行も残さない。
    func testCreateRollsBackPracticeWhenFocusRecordFails() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makePracticeRepository(db)

        var threw = false
        do {
            // 存在しない課題を参照する手応え → 外部キー制約違反
            _ = try repo.create(practiceDate: t0, minutes: 90, focus: [
                FocusEntry(issueId: 999, result: .done),
            ])
        } catch {
            threw = true
        }

        XCTAssertTrue(threw, "外部キー制約違反で失敗すること")
    }

    func testCreateLeavesNoPracticeRowWhenFocusRecordFails() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makePracticeRepository(db)

        do {
            _ = try repo.create(practiceDate: t0, minutes: 90, focus: [
                FocusEntry(issueId: 999, result: .done),
            ])
        } catch {
            // 失敗すること自体は testCreateRollsBackPracticeWhenFocusRecordFails で確認済み
        }

        let practices = try repo.fetchAll()
        XCTAssertEqual(0, practices.count, "ロールバックされ practice 行が残らないこと")
    }

    func testUpdateRollsBackPracticeWhenFocusRecordFails() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makePracticeRepository(db)

        let created = try repo.create(practiceDate: t0, minutes: 90)
        var edited = created
        edited.minutes = 120
        do {
            _ = try repo.update(edited, focus: [FocusEntry(issueId: 999, result: .done)])
        } catch {
            // 失敗は想定どおり
        }

        let fetched = try XCTUnwrap(try repo.fetch(id: created.id))
        XCTAssertEqual(90, fetched.minutes, "practice 側の変更もロールバックされること")
    }

    // MARK: - 保存し直し

    /// 同じ practice を保存し直しても focus_record が増えない。
    func testUpdateDoesNotDuplicateFocusRecords() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makePracticeRepository(db)
        let issues = makeIssueRepository(db)

        let issueA = try issues.create(coachWords: "A")
        let issueB = try issues.create(coachWords: "B")
        let entries = [
            FocusEntry(issueId: issueA.id, result: .done),
            FocusEntry(issueId: issueB.id, result: nil),
        ]
        let practice = try repo.create(practiceDate: t0, minutes: 90, focus: entries)
        _ = try repo.update(practice, focus: entries)

        let records = try repo.fetchFocusRecords(practiceId: practice.id)
        XCTAssertEqual(2, records.count)
    }

    func testUpdateOverwritesFocusResult() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makePracticeRepository(db)
        let issues = makeIssueRepository(db)

        let issue = try issues.create(coachWords: "A")
        let practice = try repo.create(practiceDate: t0, focus: [
            FocusEntry(issueId: issue.id, result: .next),
        ])
        _ = try repo.update(practice, focus: [
            FocusEntry(issueId: issue.id, result: .done),
        ])

        let records = try repo.fetchFocusRecords(practiceId: practice.id)
        let record = try XCTUnwrap(records.first)
        XCTAssertEqual(FocusResult.done, record.result)
    }

    /// 保存し直しでは手応えの集合を置き換える。外れた課題の行は残さない。
    func testUpdateRemovesFocusRecordsNoLongerPresent() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makePracticeRepository(db)
        let issues = makeIssueRepository(db)

        let issueA = try issues.create(coachWords: "A")
        let issueB = try issues.create(coachWords: "B")
        let practice = try repo.create(practiceDate: t0, focus: [
            FocusEntry(issueId: issueA.id, result: .done),
            FocusEntry(issueId: issueB.id, result: .done),
        ])
        _ = try repo.update(practice, focus: [
            FocusEntry(issueId: issueA.id, result: .done),
        ])

        let records = try repo.fetchFocusRecords(practiceId: practice.id)
        XCTAssertEqual(1, records.count)
    }

    func testUpdatePersistsPracticeAttributes() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makePracticeRepository(db)

        let created = try repo.create(practiceDate: t0, minutes: 90, kind: .whole)
        var edited = created
        edited.minutes = 120
        edited.kind = .strength
        _ = try repo.update(edited, focus: [])

        let fetched = try XCTUnwrap(try repo.fetch(id: created.id))
        XCTAssertEqual(120, fetched.minutes)
        XCTAssertEqual(PracticeKind.strength, fetched.kind)
    }

    // MARK: - 課題ごとの累計時間

    /// 1 練習の minutes は重点課題それぞれに満額計上する(按分しない)。
    func testTotalMinutesCountsFullMinutesForEachIssue() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makePracticeRepository(db)
        let issues = makeIssueRepository(db)

        let issueA = try issues.create(coachWords: "A")
        let issueB = try issues.create(coachWords: "B")
        _ = try repo.create(practiceDate: t0, minutes: 90, focus: [
            FocusEntry(issueId: issueA.id, result: .done),
            FocusEntry(issueId: issueB.id, result: .done),
        ])

        XCTAssertEqual(90, try repo.totalMinutes(issueId: issueA.id))
        XCTAssertEqual(90, try repo.totalMinutes(issueId: issueB.id))
    }

    func testTotalMinutesSumsEveryPracticeForIssue() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makePracticeRepository(db)
        let issues = makeIssueRepository(db)

        let issue = try issues.create(coachWords: "A")
        _ = try repo.create(practiceDate: t0, minutes: 90, focus: [
            FocusEntry(issueId: issue.id, result: .done),
        ])
        _ = try repo.create(practiceDate: t1, minutes: 60, focus: [
            FocusEntry(issueId: issue.id, result: .closer),
        ])

        let total = try repo.totalMinutes(issueId: issue.id)

        XCTAssertEqual(150, total)
    }

    /// 手応え未入力の練習も累計時間に含める。
    func testTotalMinutesCountsRecordsWithoutResult() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makePracticeRepository(db)
        let issues = makeIssueRepository(db)

        let issue = try issues.create(coachWords: "A")
        _ = try repo.create(practiceDate: t0, minutes: 90, focus: [
            FocusEntry(issueId: issue.id, result: nil),
        ])

        let total = try repo.totalMinutes(issueId: issue.id)

        XCTAssertEqual(90, total)
    }

    func testTotalMinutesIsZeroWhenIssueHasNoRecords() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makePracticeRepository(db)
        let issues = makeIssueRepository(db)

        let issue = try issues.create(coachWords: "A")
        _ = try repo.create(practiceDate: t0, minutes: 90)

        let total = try repo.totalMinutes(issueId: issue.id)

        XCTAssertEqual(0, total, "SUM が NULL のときは 0")
    }

    // MARK: - Delete

    func testDeleteRemovesPractice() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makePracticeRepository(db)

        let practice = try repo.create(practiceDate: t0, minutes: 90)
        try repo.delete(id: practice.id)

        let fetched = try repo.fetch(id: practice.id)
        XCTAssertNil(fetched)
    }

    /// practice を消すと focus_record も消える(ON DELETE CASCADE)。
    func testDeleteCascadesToFocusRecords() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makePracticeRepository(db)
        let issues = makeIssueRepository(db)

        let issueA = try issues.create(coachWords: "A")
        let issueB = try issues.create(coachWords: "B")
        let practice = try repo.create(practiceDate: t0, minutes: 90, focus: [
            FocusEntry(issueId: issueA.id, result: .done),
            FocusEntry(issueId: issueB.id, result: nil),
        ])
        try repo.delete(id: practice.id)

        let rows = try db.selectAll(sql: "SELECT COUNT(*) FROM focus_record")
        let remaining = try XCTUnwrap(rows.first?.first?.longValue)
        XCTAssertEqual(Int64(0), remaining)
    }

    /// カスケードで消えるのは手応えだけ。課題そのものは残す。
    func testDeleteKeepsIssues() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makePracticeRepository(db)
        let issues = makeIssueRepository(db)

        let issue = try issues.create(coachWords: "A")
        let practice = try repo.create(practiceDate: t0, minutes: 90, focus: [
            FocusEntry(issueId: issue.id, result: .done),
        ])
        try repo.delete(id: practice.id)

        let fetched = try issues.fetch(id: issue.id)
        XCTAssertNotNil(fetched)
    }

    /// 累計時間の集計元が消えるので、削除後は 0 に戻る。
    func testDeleteRemovesPracticeFromTotalMinutes() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makePracticeRepository(db)
        let issues = makeIssueRepository(db)

        let issue = try issues.create(coachWords: "A")
        let practice = try repo.create(practiceDate: t0, minutes: 90, focus: [
            FocusEntry(issueId: issue.id, result: .done),
        ])
        try repo.delete(id: practice.id)

        let total = try repo.totalMinutes(issueId: issue.id)
        XCTAssertEqual(0, total)
    }

    // MARK: - Read

    func testFetchReturnsNilForUnknownIdentifier() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makePracticeRepository(db)

        let fetched = try repo.fetch(id: 999)

        XCTAssertNil(fetched)
    }

    func testFetchAllReturnsNewestFirst() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makePracticeRepository(db)

        _ = try repo.create(practiceDate: t0, minutes: 60)
        _ = try repo.create(practiceDate: t1, minutes: 90)

        let practices = try repo.fetchAll()

        XCTAssertEqual([90, 60], practices.map { $0.minutes })
    }

    func testFetchAllReturnsEmptyArrayWhenNoPractices() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makePracticeRepository(db)

        let practices = try repo.fetchAll()

        XCTAssertEqual(0, practices.count)
    }

    // MARK: - 期間の合計時間

    /// §7.2 保存後に出す「今月の累計」の集計。
    func testTotalMinutesInRangeSumsPracticesInside() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makePracticeRepository(db)

        _ = try repo.create(practiceDate: t0, minutes: 90)
        _ = try repo.create(practiceDate: t1, minutes: 60)

        let total = try repo.totalMinutes(from: t0, to: Date(timeIntervalSince1970: 1_700_010_000))

        XCTAssertEqual(150, total)
    }

    /// 境界: 開始日ちょうどは含む。
    func testTotalMinutesInRangeIncludesStart() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makePracticeRepository(db)

        _ = try repo.create(practiceDate: t0, minutes: 90)

        let total = try repo.totalMinutes(from: t0, to: t1)

        XCTAssertEqual(90, total)
    }

    /// 境界: 終了日ちょうどは含まない(半開区間)。翌月の頭を渡せる形にするため。
    func testTotalMinutesInRangeExcludesEnd() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makePracticeRepository(db)

        _ = try repo.create(practiceDate: t1, minutes: 90)

        let total = try repo.totalMinutes(from: t0, to: t1)

        XCTAssertEqual(0, total)
    }

    func testTotalMinutesInRangeExcludesPracticesBeforeStart() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makePracticeRepository(db)

        _ = try repo.create(practiceDate: Date(timeIntervalSince1970: 1_699_000_000), minutes: 90)

        let total = try repo.totalMinutes(from: t0, to: t1)

        XCTAssertEqual(0, total)
    }

    func testTotalMinutesInRangeIsZeroWhenNoPractices() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makePracticeRepository(db)

        let total = try repo.totalMinutes(from: t0, to: t1)

        XCTAssertEqual(0, total)
    }

    // MARK: - 課題ごとの手応え履歴

    /// §3.2 のレベルアップ判定に渡す履歴。**新しい練習が先**。
    func testFetchFocusResultsReturnsNewestFirst() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makePracticeRepository(db)
        let issues = makeIssueRepository(db)

        let issue = try issues.create(coachWords: "A")
        _ = try repo.create(practiceDate: t0, focus: [FocusEntry(issueId: issue.id, result: .closer)])
        _ = try repo.create(practiceDate: t1, focus: [FocusEntry(issueId: issue.id, result: .done)])

        let results = try repo.fetchFocusResults(issueId: issue.id)

        XCTAssertEqual([FocusResult.done, FocusResult.closer], results)
    }

    /// 未入力(NULL)も履歴に含める。連続判定側が飛ばして数える。
    func testFetchFocusResultsIncludesNilResults() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makePracticeRepository(db)
        let issues = makeIssueRepository(db)

        let issue = try issues.create(coachWords: "A")
        _ = try repo.create(practiceDate: t0, focus: [FocusEntry(issueId: issue.id, result: nil)])

        let results = try repo.fetchFocusResults(issueId: issue.id)

        XCTAssertEqual(1, results.count)
        XCTAssertNil(results.first ?? nil)
    }

    func testFetchFocusResultsExcludesOtherIssues() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makePracticeRepository(db)
        let issues = makeIssueRepository(db)

        let first = try issues.create(coachWords: "A")
        let second = try issues.create(coachWords: "B")
        _ = try repo.create(practiceDate: t0, focus: [
            FocusEntry(issueId: first.id, result: .done),
            FocusEntry(issueId: second.id, result: .closer),
        ])

        let results = try repo.fetchFocusResults(issueId: first.id)

        XCTAssertEqual([FocusResult.done], results)
    }

    func testFetchFocusResultsIsEmptyForUntouchedIssue() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makePracticeRepository(db)
        let issues = makeIssueRepository(db)

        let issue = try issues.create(coachWords: "A")

        let results = try repo.fetchFocusResults(issueId: issue.id)

        XCTAssertEqual(0, results.count)
    }

    // MARK: - 練習の総数

    /// §7.1 の「数回使った後に促す」の判定材料。
    func testCountReturnsNumberOfPractices() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makePracticeRepository(db)

        _ = try repo.create(practiceDate: t0)
        _ = try repo.create(practiceDate: t1)

        XCTAssertEqual(2, try repo.count())
    }

    func testCountIsZeroWithoutPractices() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makePracticeRepository(db)

        XCTAssertEqual(0, try repo.count())
    }
}
