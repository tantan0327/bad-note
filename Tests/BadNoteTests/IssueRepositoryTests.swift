import XCTest
import Foundation
import SkipSQL
@testable import BadNote

/// `IssueRepository` の仕様。対象は issue テーブルの CRUD と tier / status による絞り込みのみ。
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
        try AppDatabase.prepare(db)
        return db
    }

    private func makeRepository(_ db: SQLContext) -> IssueRepository {
        clock = t0
        return IssueRepository(db: db, now: { self.clock })
    }

    private func makeTagRepository(_ db: SQLContext) -> TagRepository {
        return TagRepository(db: db)
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

    /// 原文も更新できる(2026-08-24 決定 —— 誤入力を直せるようにする)。
    func testUpdatePersistsCoachWords() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let created = try repo.create(coachWords: "もっとラケット面、下むいてるよ")
        var edited = created
        edited.coachWords = "もっとラケット面、下向いてるよ"
        _ = try repo.update(edited)

        let fetched = try XCTUnwrap(try repo.fetch(id: created.id))
        XCTAssertEqual("もっとラケット面、下向いてるよ", fetched.coachWords)
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

    // MARK: - Status による絞り込み

    func testFetchByStatusReturnsOnlyThatStatus() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        _ = try repo.create(coachWords: "未整理", status: .inbox)
        _ = try repo.create(coachWords: "取り組み中", status: .active)
        _ = try repo.create(coachWords: "定着済み", status: .archived)

        let archived = try repo.fetch(statuses: [.archived])

        XCTAssertEqual(["定着済み"], archived.map { $0.coachWords })
    }

    /// §4.2 の評価対象 `status IN ('inbox','active')` のように複数指定できること。
    func testFetchByStatusAcceptsMultipleStatuses() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        _ = try repo.create(coachWords: "未整理", status: .inbox)
        _ = try repo.create(coachWords: "取り組み中", status: .active)
        _ = try repo.create(coachWords: "定着済み", status: .archived)

        let living = try repo.fetch(statuses: [.inbox, .active])

        XCTAssertEqual(["未整理", "取り組み中"], living.map { $0.coachWords })
    }

    /// §7.4 アーカイブは一覧に出さない。tier と status の両方が AND で効くこと。
    func testFetchByTierAndStatusAppliesBothConditions() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        _ = try repo.create(coachWords: "重点・未整理", tier: .focus, status: .inbox)
        _ = try repo.create(coachWords: "重点・定着済み", tier: .focus, status: .archived)
        _ = try repo.create(coachWords: "いつか・未整理", tier: .someday, status: .inbox)

        let focused = try repo.fetch(tier: .focus, statuses: [.inbox, .active])

        XCTAssertEqual(["重点・未整理"], focused.map { $0.coachWords })
    }

    /// status を渡さなければ絞り込まない。既定で黙ってアーカイブを隠さないこと。
    func testFetchWithoutStatusesIncludesArchived() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        _ = try repo.create(coachWords: "重点・未整理", tier: .focus, status: .inbox)
        _ = try repo.create(coachWords: "重点・定着済み", tier: .focus, status: .archived)

        let focused = try repo.fetch(tier: .focus)

        XCTAssertEqual(2, focused.count)
    }

    func testFetchWithStatusesOnlyIgnoresTier() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        _ = try repo.create(coachWords: "重点", tier: .focus, status: .active)
        _ = try repo.create(coachWords: "いつか", tier: .someday, status: .active)
        _ = try repo.create(coachWords: "定着済み", tier: .someday, status: .archived)

        let living = try repo.fetch(statuses: [.inbox, .active])

        XCTAssertEqual(2, living.count)
    }

    /// 空配列は「どの status にも該当しない」。SQL の `IN ()` にしない。
    func testFetchWithEmptyStatusesReturnsNothing() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        _ = try repo.create(coachWords: "未整理", status: .inbox)

        let result = try repo.fetch(statuses: [])

        XCTAssertEqual(0, result.count)
    }

    func testFetchByStatusOrdersBySortOrder() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        _ = try repo.create(coachWords: "2番目", sortOrder: 1, status: .active)
        _ = try repo.create(coachWords: "1番目", sortOrder: 0, status: .active)

        let living = try repo.fetch(statuses: [.active])

        XCTAssertEqual(["1番目", "2番目"], living.map { $0.coachWords })
    }

    // MARK: - Tag による絞り込み

    func testFetchByTagReturnsOnlyTaggedIssues() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)
        let tags = makeTagRepository(db)

        let tagged = try repo.create(coachWords: "スマッシュのあと戻りが遅い")
        _ = try repo.create(coachWords: "レシーブでラケット面が下向き")
        let smash = try tags.create(name: "スマッシュ")
        try tags.attach(tagId: smash.id, to: tagged.id)

        let found = try repo.fetch(tagId: smash.id)

        XCTAssertEqual(["スマッシュのあと戻りが遅い"], found.map { $0.coachWords })
    }

    /// §7.4 絞り込みは組み合わせられる。tier / status / タグが AND で効くこと。
    func testFetchByTagCombinesWithTier() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)
        let tags = makeTagRepository(db)

        let focused = try repo.create(coachWords: "重点", tier: .focus)
        let someday = try repo.create(coachWords: "いつか", tier: .someday)
        let smash = try tags.create(name: "スマッシュ")
        try tags.attach(tagId: smash.id, to: focused.id)
        try tags.attach(tagId: smash.id, to: someday.id)

        let found = try repo.fetch(tier: .focus, tagId: smash.id)

        XCTAssertEqual(["重点"], found.map { $0.coachWords })
    }

    func testFetchByTagReturnsEmptyArrayWhenNoneTagged() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)
        let tags = makeTagRepository(db)

        _ = try repo.create(coachWords: "A")
        let smash = try tags.create(name: "スマッシュ")

        let found = try repo.fetch(tagId: smash.id)

        XCTAssertEqual(0, found.count)
    }

    /// §7.4 既定はフィルタなし。タグを渡さなければ未タグの課題も返る。
    func testFetchWithoutTagIncludesUntaggedIssues() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)
        let tags = makeTagRepository(db)

        let tagged = try repo.create(coachWords: "A")
        _ = try repo.create(coachWords: "B")
        let smash = try tags.create(name: "スマッシュ")
        try tags.attach(tagId: smash.id, to: tagged.id)

        let all = try repo.fetch()

        XCTAssertEqual(2, all.count)
    }

    func testFetchByTagOrdersBySortOrder() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)
        let tags = makeTagRepository(db)

        let second = try repo.create(coachWords: "2番目", sortOrder: 1)
        let first = try repo.create(coachWords: "1番目", sortOrder: 0)
        let smash = try tags.create(name: "スマッシュ")
        try tags.attach(tagId: smash.id, to: second.id)
        try tags.attach(tagId: smash.id, to: first.id)

        let found = try repo.fetch(tagId: smash.id)

        XCTAssertEqual(["1番目", "2番目"], found.map { $0.coachWords })
    }

    // MARK: - レベルアップ提案の抑制

    /// §3.2「1 度だけ提案する」ための記録。新規では何も断っていない。
    func testCreateLeavesLevelUpDeclinedLevelNil() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let issue = try repo.create(coachWords: "A")

        XCTAssertNil(issue.levelUpDeclinedLevel)
    }

    func testUpdatePersistsLevelUpDeclinedLevel() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let created = try repo.create(coachWords: "A")
        var edited = created
        edited.levelUpDeclinedLevel = 1
        _ = try repo.update(edited)

        let fetched = try XCTUnwrap(try repo.fetch(id: created.id))
        XCTAssertEqual(1, fetched.levelUpDeclinedLevel)
    }

    // MARK: - アーカイブ(§7.4 これまでに定着した課題)

    /// 達成の記録として見る画面なので、**新しく定着したものが先**。
    func testFetchArchivedReturnsNewestFirst() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let first = try repo.create(coachWords: "先に定着")
        let second = try repo.create(coachWords: "後で定着")
        var editedFirst = first
        editedFirst.status = .archived
        editedFirst.archivedAt = t0
        _ = try repo.update(editedFirst)
        var editedSecond = second
        editedSecond.status = .archived
        editedSecond.archivedAt = t1
        _ = try repo.update(editedSecond)

        let archived = try repo.fetchArchived()

        XCTAssertEqual(["後で定着", "先に定着"], archived.map { $0.coachWords })
    }

    func testFetchArchivedExcludesActiveIssues() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        _ = try repo.create(coachWords: "取り組み中", status: .active)

        XCTAssertEqual(0, try repo.fetchArchived().count)
    }

    func testFetchArchivedIsEmptyWhenNothingArchived() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        XCTAssertEqual(0, try repo.fetchArchived().count)
    }

    // MARK: - 種目と習熟度による絞り込み(§7.4)

    /// §3.5 / §7.5 **`both` の課題は両方の種目に出す。**
    func testFetchByDisciplineIncludesBothIssues() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        _ = try repo.create(coachWords: "シングルス専用", discipline: .singles)
        _ = try repo.create(coachWords: "両方", discipline: .both)
        _ = try repo.create(coachWords: "ダブルス専用", discipline: .doubles)

        let singles = try repo.fetch(discipline: .singles)

        XCTAssertEqual(["シングルス専用", "両方"], singles.map { $0.coachWords })
    }

    func testFetchByDisciplineIncludesBothForDoubles() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        _ = try repo.create(coachWords: "シングルス専用", discipline: .singles)
        _ = try repo.create(coachWords: "両方", discipline: .both)

        let doubles = try repo.fetch(discipline: .doubles)

        XCTAssertEqual(["両方"], doubles.map { $0.coachWords })
    }

    /// `both` で絞り込むと `both` の課題だけ(種目を問わない課題の一覧)。
    func testFetchByBothDisciplineReturnsOnlyBoth() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        _ = try repo.create(coachWords: "シングルス専用", discipline: .singles)
        _ = try repo.create(coachWords: "両方", discipline: .both)

        XCTAssertEqual(["両方"], try repo.fetch(discipline: .both).map { $0.coachWords })
    }

    func testFetchByMasteryLevel() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        _ = try repo.create(coachWords: "素振り", masteryLevel: .solo)
        _ = try repo.create(coachWords: "試合", masteryLevel: .match)

        XCTAssertEqual(["試合"], try repo.fetch(masteryLevel: .match).map { $0.coachWords })
    }

    /// §7.4 既定はフィルタなし。何も渡さなければ全部返る。
    func testFetchWithoutFiltersReturnsEverything() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        _ = try repo.create(coachWords: "A", discipline: .singles, masteryLevel: .solo)
        _ = try repo.create(coachWords: "B", discipline: .doubles, masteryLevel: .match)

        XCTAssertEqual(2, try repo.fetch().count)
    }

    /// 絞り込みは組み合わせられる。
    func testFiltersCombine() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        _ = try repo.create(coachWords: "対象", discipline: .singles, masteryLevel: .match, tier: .focus)
        _ = try repo.create(coachWords: "種目違い", discipline: .doubles, masteryLevel: .match, tier: .focus)
        _ = try repo.create(coachWords: "レベル違い", discipline: .singles, masteryLevel: .solo, tier: .focus)

        let found = try repo.fetch(tier: .focus, discipline: .singles, masteryLevel: .match)

        XCTAssertEqual(["対象"], found.map { $0.coachWords })
    }

    // MARK: - 断った記録(§3.2)

    /// 新しい列の既定は nil(まだ断っていない)。
    func testStepDownDeclinedLevelStartsNil() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let issue = try repo.create(coachWords: "ハイクリアが浅い")

        XCTAssertNil(issue.stepDownDeclinedLevel)
    }

    func testStepDownDeclinedLevelRoundTrip() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)
        var issue = try repo.create(coachWords: "ハイクリアが浅い")

        issue.stepDownDeclinedLevel = 2
        let saved = try repo.update(issue)

        XCTAssertEqual(2, saved.stepDownDeclinedLevel)
    }

    /// **段が変わったら断った記録は 2 列とも消える。**
    ///
    /// 呼び出し側に書かせると、レベルを変える経路(提案の承認 / 手動の上げ下げ /
    /// 再浮上)× 列の数だけ書き忘れが起きる。`update` の中で一度に消す。
    func testChangingTheLevelClearsBothDeclinedColumns() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)
        var issue = try repo.create(coachWords: "ハイクリアが浅い")
        issue.levelUpDeclinedLevel = 1
        issue.stepDownDeclinedLevel = 1
        issue = try repo.update(issue)

        issue.masteryLevel = MasteryLevel.drill
        let saved = try repo.update(issue)

        XCTAssertNil(saved.levelUpDeclinedLevel)
        XCTAssertNil(saved.stepDownDeclinedLevel)
    }

    /// 段が変わらない更新では消さない(断ったことを覚えておく)。
    func testUpdatingWithoutLevelChangeKeepsDeclinedColumns() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)
        var issue = try repo.create(coachWords: "ハイクリアが浅い")
        issue.levelUpDeclinedLevel = 1
        issue.stepDownDeclinedLevel = 1
        issue = try repo.update(issue)

        issue.coachName = "コーチ"
        let saved = try repo.update(issue)

        XCTAssertEqual(1, saved.levelUpDeclinedLevel)
        XCTAssertEqual(1, saved.stepDownDeclinedLevel)
    }
}
