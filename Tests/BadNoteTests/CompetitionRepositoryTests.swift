import XCTest
import Foundation
import SkipSQL
@testable import BadNote

/// `CompetitionRepository` の仕様。対象は `competition` と `competition_entry`。
///
/// - スキーマは `docs/spec.md` §6
/// - DB はテストごとに新規のインメモリ(`SQLContext(configuration: .platform)`)
/// - 時刻は注入したクロックから取る。実時刻に依存させない
final class CompetitionRepositoryTests: XCTestCase {

    /// 2023-11-14T22:13:20Z。判定の基準時刻。
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    /// t0 の 7 日前 = 終了した大会
    private let past = Date(timeIntervalSince1970: 1_699_395_200)
    /// t0 の 1 日後 = 近いこれからの大会
    private let soon = Date(timeIntervalSince1970: 1_700_086_400)
    /// t0 の 30 日後 = 遠いこれからの大会
    private let later = Date(timeIntervalSince1970: 1_702_592_000)

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

    // MARK: - Create

    func testCreateAssignsIdentifier() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let competition = try repo.create(name: "県大会", eventDate: soon)

        XCTAssertTrue(competition.id > 0)
    }

    func testCreateStoresCompetitionAttributes() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let created = try repo.create(name: "県大会", eventDate: soon, venue: "市民体育館")

        let fetched = try XCTUnwrap(try repo.fetch(id: created.id))
        XCTAssertEqual(created, fetched, "create の戻り値と fetch の結果が一致すること")
    }

    func testCreateAllowsNilVenue() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let competition = try repo.create(name: "県大会", eventDate: soon)

        XCTAssertNil(competition.venue)
    }

    func testCreateTakesCreatedAtFromClock() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let competition = try repo.create(name: "県大会", eventDate: soon)

        XCTAssertEqual(t0, competition.createdAt)
    }

    /// §4.2 タイムスタンプは UTC の ISO 8601 TEXT で統一する。
    /// カウントダウン(§7.1)と調整期の判定(§4.4)がこの値を基準にする。
    func testEventDateIsStoredAsUTCISO8601Text() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let competition = try repo.create(name: "県大会", eventDate: t0)

        let rows = try db.selectAll(sql: "SELECT event_date FROM competition WHERE id = ?",
                                    parameters: [.long(competition.id)])
        let storedText = try XCTUnwrap(rows.first?.first?.textValue)
        XCTAssertEqual("2023-11-14T22:13:20Z", storedText)
    }

    // MARK: - 種目エントリー

    /// §6 1 大会が複数種目を持てる。
    func testCreateStoresEntriesForBothDisciplines() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let competition = try repo.create(name: "県大会", eventDate: soon, entries: [
            CompetitionEntry(discipline: .singles),
            CompetitionEntry(discipline: .doubles),
        ])

        let entries = try repo.fetchEntries(competitionId: competition.id)

        XCTAssertEqual([Discipline.singles, Discipline.doubles], entries.map { $0.discipline })
    }

    func testCreateDefaultsIsTargetToFalse() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let competition = try repo.create(name: "県大会", eventDate: soon, entries: [
            CompetitionEntry(discipline: .singles),
        ])

        let entries = try repo.fetchEntries(competitionId: competition.id)
        let entry = try XCTUnwrap(entries.first)
        XCTAssertFalse(entry.isTarget)
    }

    func testCreateStoresIsTargetFlag() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let competition = try repo.create(name: "県大会", eventDate: soon, entries: [
            CompetitionEntry(discipline: .singles, isTarget: true),
        ])

        let entries = try repo.fetchEntries(competitionId: competition.id)
        let entry = try XCTUnwrap(entries.first)
        XCTAssertTrue(entry.isTarget)
    }

    /// §6 competition_entry.discipline は 'singles' | 'doubles' のみ。
    /// `both` は課題の既定値であって、大会のエントリー種目にはならない。
    func testCreateRejectsBothDisciplineForEntry() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        var threw = false
        do {
            _ = try repo.create(name: "県大会", eventDate: soon, entries: [
                CompetitionEntry(discipline: .both),
            ])
        } catch {
            threw = true
        }

        XCTAssertTrue(threw)
    }

    /// §6 UNIQUE (competition_id, discipline)。同じ種目を 2 つ渡したら失敗する。
    func testCreateRejectsDuplicateDisciplines() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        var threw = false
        do {
            _ = try repo.create(name: "県大会", eventDate: soon, entries: [
                CompetitionEntry(discipline: .singles),
                CompetitionEntry(discipline: .singles),
            ])
        } catch {
            threw = true
        }

        XCTAssertTrue(threw)
    }

    /// 大会とエントリーは 1 トランザクション。
    /// 2 件目のエントリーで失敗しても、先に INSERT された competition 行は残らない。
    func testCreateLeavesNoCompetitionRowWhenSecondEntryFails() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        do {
            _ = try repo.create(name: "県大会", eventDate: soon, entries: [
                CompetitionEntry(discipline: .singles),
                CompetitionEntry(discipline: .singles),
            ])
        } catch {
            // 失敗は testCreateRejectsDuplicateDisciplines で確認済み
        }

        let all = try repo.fetchAll()
        XCTAssertEqual(0, all.count, "ロールバックされ competition 行が残らないこと")
    }

    func testFetchTargetRejectsBothDiscipline() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        var threw = false
        do {
            _ = try repo.fetchTarget(discipline: .both)
        } catch {
            threw = true
        }

        XCTAssertTrue(threw)
    }

    // MARK: - 目標大会

    func testFetchTargetReturnsCompetitionForDiscipline() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let created = try repo.create(name: "県大会", eventDate: soon, entries: [
            CompetitionEntry(discipline: .singles, isTarget: true),
        ])

        let target = try repo.fetchTarget(discipline: .singles)

        XCTAssertEqual(created, target)
    }

    func testFetchTargetReturnsNilWhenNoTarget() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        _ = try repo.create(name: "県大会", eventDate: soon, entries: [
            CompetitionEntry(discipline: .singles),
        ])

        let target = try repo.fetchTarget(discipline: .singles)

        XCTAssertNil(target)
    }

    /// エントリーの無い種目の目標は nil。
    func testFetchTargetReturnsNilForDisciplineWithoutEntry() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        _ = try repo.create(name: "県大会", eventDate: soon, entries: [
            CompetitionEntry(discipline: .singles, isTarget: true),
        ])

        let target = try repo.fetchTarget(discipline: .doubles)

        XCTAssertNil(target)
    }

    /// §6 is_target = 1 は discipline ごとに最大 1 件。
    /// 別の大会を目標にしたら、同じ種目の既存の目標は自動で解除される。
    func testSettingTargetClearsPreviousTargetForSameDiscipline() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let first = try repo.create(name: "地区大会", eventDate: soon, entries: [
            CompetitionEntry(discipline: .singles, isTarget: true),
        ])
        let second = try repo.create(name: "県大会", eventDate: later, entries: [
            CompetitionEntry(discipline: .singles, isTarget: true),
        ])

        let target = try repo.fetchTarget(discipline: .singles)

        XCTAssertEqual(second, target, "後から設定した大会が目標になること")
        XCTAssertNotEqual(first, target)
    }

    func testSettingTargetLeavesPreviousCompetitionEntryInPlace() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let first = try repo.create(name: "地区大会", eventDate: soon, entries: [
            CompetitionEntry(discipline: .singles, isTarget: true),
        ])
        _ = try repo.create(name: "県大会", eventDate: later, entries: [
            CompetitionEntry(discipline: .singles, isTarget: true),
        ])

        let entries = try repo.fetchEntries(competitionId: first.id)
        let entry = try XCTUnwrap(entries.first)
        XCTAssertFalse(entry.isTarget, "解除されるのは目標フラグだけで、エントリー自体は残ること")
    }

    /// §7.5 目標大会は種目ごとに独立。singles の目標を変えても doubles は動かない。
    func testSettingTargetKeepsTargetOfOtherDiscipline() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let doublesTarget = try repo.create(name: "地区大会", eventDate: soon, entries: [
            CompetitionEntry(discipline: .doubles, isTarget: true),
        ])
        _ = try repo.create(name: "県大会", eventDate: later, entries: [
            CompetitionEntry(discipline: .singles, isTarget: true),
        ])

        let target = try repo.fetchTarget(discipline: .doubles)

        XCTAssertEqual(doublesTarget, target)
    }

    /// 1 つの大会が singles と doubles の両方の目標になれる。
    func testCompetitionCanBeTargetForBothDisciplines() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let created = try repo.create(name: "県大会", eventDate: soon, entries: [
            CompetitionEntry(discipline: .singles, isTarget: true),
            CompetitionEntry(discipline: .doubles, isTarget: true),
        ])

        XCTAssertEqual(created, try repo.fetchTarget(discipline: .singles))
        XCTAssertEqual(created, try repo.fetchTarget(discipline: .doubles))
    }

    func testUpdateSettingTargetClearsPreviousTarget() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        _ = try repo.create(name: "地区大会", eventDate: soon, entries: [
            CompetitionEntry(discipline: .singles, isTarget: true),
        ])
        let second = try repo.create(name: "県大会", eventDate: later, entries: [
            CompetitionEntry(discipline: .singles),
        ])
        _ = try repo.update(second, entries: [
            CompetitionEntry(discipline: .singles, isTarget: true),
        ])

        let target = try repo.fetchTarget(discipline: .singles)

        XCTAssertEqual(second, target)
    }

    func testUpdateCanClearTarget() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let created = try repo.create(name: "県大会", eventDate: soon, entries: [
            CompetitionEntry(discipline: .singles, isTarget: true),
        ])
        _ = try repo.update(created, entries: [
            CompetitionEntry(discipline: .singles, isTarget: false),
        ])

        let target = try repo.fetchTarget(discipline: .singles)

        XCTAssertNil(target)
    }

    // MARK: - これからの大会 / 終了した大会

    /// §7.5 これからの大会を日付順、下に終了した大会。
    func testFetchUpcomingReturnsOnlyFutureCompetitions() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        _ = try repo.create(name: "終わった大会", eventDate: past)
        _ = try repo.create(name: "これからの大会", eventDate: soon)

        let upcoming = try repo.fetchUpcoming(asOf: t0)

        XCTAssertEqual(["これからの大会"], upcoming.map { $0.name })
    }

    func testFetchUpcomingOrdersByNearestFirst() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        _ = try repo.create(name: "遠い大会", eventDate: later)
        _ = try repo.create(name: "近い大会", eventDate: soon)

        let upcoming = try repo.fetchUpcoming(asOf: t0)

        XCTAssertEqual(["近い大会", "遠い大会"], upcoming.map { $0.name })
    }

    /// 境界は当日を含む。呼び出し側が「今日の 0 時」を渡せば当日の大会は
    /// これからの大会として出る。
    func testFetchUpcomingIncludesCompetitionExactlyAtAsOf() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        _ = try repo.create(name: "今まさに", eventDate: t0)

        let upcoming = try repo.fetchUpcoming(asOf: t0)

        XCTAssertEqual(1, upcoming.count)
    }

    func testFetchFinishedReturnsOnlyPastCompetitions() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        _ = try repo.create(name: "終わった大会", eventDate: past)
        _ = try repo.create(name: "これからの大会", eventDate: soon)

        let finished = try repo.fetchFinished(asOf: t0)

        XCTAssertEqual(["終わった大会"], finished.map { $0.name })
    }

    func testFetchFinishedOrdersByMostRecentFirst() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        // past より更に 7 日前
        let older = Date(timeIntervalSince1970: 1_698_790_400)
        _ = try repo.create(name: "古い大会", eventDate: older)
        _ = try repo.create(name: "最近の大会", eventDate: past)

        let finished = try repo.fetchFinished(asOf: t0)

        XCTAssertEqual(["最近の大会", "古い大会"], finished.map { $0.name })
    }

    func testFetchFinishedExcludesCompetitionExactlyAtAsOf() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        _ = try repo.create(name: "今まさに", eventDate: t0)

        let finished = try repo.fetchFinished(asOf: t0)

        XCTAssertEqual(0, finished.count)
    }

    // MARK: - 保存し直し

    func testUpdateDoesNotDuplicateEntries() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let entries = [
            CompetitionEntry(discipline: .singles),
            CompetitionEntry(discipline: .doubles),
        ]
        let created = try repo.create(name: "県大会", eventDate: soon, entries: entries)
        _ = try repo.update(created, entries: entries)

        let stored = try repo.fetchEntries(competitionId: created.id)
        XCTAssertEqual(2, stored.count)
    }

    func testUpdateRemovesEntriesNoLongerPresent() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let created = try repo.create(name: "県大会", eventDate: soon, entries: [
            CompetitionEntry(discipline: .singles),
            CompetitionEntry(discipline: .doubles),
        ])
        _ = try repo.update(created, entries: [
            CompetitionEntry(discipline: .singles),
        ])

        let stored = try repo.fetchEntries(competitionId: created.id)
        XCTAssertEqual([Discipline.singles], stored.map { $0.discipline })
    }

    func testUpdatePersistsCompetitionAttributes() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let created = try repo.create(name: "県大会", eventDate: soon)
        var edited = created
        edited.name = "県大会(会場変更)"
        edited.eventDate = later
        edited.venue = "総合体育館"
        _ = try repo.update(edited, entries: [])

        let fetched = try XCTUnwrap(try repo.fetch(id: created.id))
        XCTAssertEqual("県大会(会場変更)", fetched.name)
        XCTAssertEqual(later, fetched.eventDate)
        XCTAssertEqual("総合体育館", fetched.venue)
    }

    // MARK: - Delete

    func testDeleteRemovesCompetition() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let created = try repo.create(name: "県大会", eventDate: soon)
        try repo.delete(id: created.id)

        let fetched = try repo.fetch(id: created.id)
        XCTAssertNil(fetched)
    }

    /// competition を消すと competition_entry も消える(ON DELETE CASCADE)。
    func testDeleteCascadesToEntries() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let created = try repo.create(name: "県大会", eventDate: soon, entries: [
            CompetitionEntry(discipline: .singles),
            CompetitionEntry(discipline: .doubles),
        ])
        try repo.delete(id: created.id)

        let rows = try db.selectAll(sql: "SELECT COUNT(*) FROM competition_entry")
        let remaining = try XCTUnwrap(rows.first?.first?.longValue)
        XCTAssertEqual(Int64(0), remaining)
    }

    func testDeleteClearsTarget() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let created = try repo.create(name: "県大会", eventDate: soon, entries: [
            CompetitionEntry(discipline: .singles, isTarget: true),
        ])
        try repo.delete(id: created.id)

        let target = try repo.fetchTarget(discipline: .singles)
        XCTAssertNil(target)
    }

    // MARK: - Read

    func testFetchReturnsNilForUnknownIdentifier() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let fetched = try repo.fetch(id: 999)

        XCTAssertNil(fetched)
    }

    func testFetchAllReturnsEveryCompetition() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        _ = try repo.create(name: "地区大会", eventDate: past)
        _ = try repo.create(name: "県大会", eventDate: soon)

        let all = try repo.fetchAll()

        XCTAssertEqual(2, all.count)
    }

    func testFetchEntriesReturnsEmptyArrayForCompetitionWithoutEntries() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let created = try repo.create(name: "県大会", eventDate: soon)

        let entries = try repo.fetchEntries(competitionId: created.id)

        XCTAssertEqual(0, entries.count)
    }

    // MARK: - 終わった大会の目標フラグ(§7.5)

    /// 過ぎた大会は「目標大会」ではなくなる。**過去の大会が目標であり続けない。**
    func testClearFinishedTargetsDropsPastTarget() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)
        _ = try repo.create(name: "終わった大会",
                            eventDate: past,
                            entries: [CompetitionEntry(discipline: .singles, isTarget: true)])

        try repo.clearFinishedTargets(asOf: t0)

        XCTAssertNil(try repo.fetchTarget(discipline: .singles))
    }

    /// エントリー種目そのものは消さない(出場した記録は残す)。
    func testClearFinishedTargetsKeepsEntryRow() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)
        let created = try repo.create(name: "終わった大会",
                                      eventDate: past,
                                      entries: [CompetitionEntry(discipline: .singles, isTarget: true)])

        try repo.clearFinishedTargets(asOf: t0)

        let entries = try repo.fetchEntries(competitionId: created.id)
        XCTAssertEqual(1, entries.count)
        XCTAssertFalse(entries[0].isTarget)
    }

    /// これからの大会の目標はそのまま。
    func testClearFinishedTargetsKeepsUpcomingTarget() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)
        _ = try repo.create(name: "これからの大会",
                            eventDate: later,
                            entries: [CompetitionEntry(discipline: .singles, isTarget: true)])

        try repo.clearFinishedTargets(asOf: t0)

        var target: Competition = try XCTUnwrap(repo.fetchTarget(discipline: .singles))
        XCTAssertEqual(target.name, "これからの大会")
    }

    /// **当日の大会はまだ目標のまま**(`asOf` に今日の 0 時を渡す約束。
    /// 当日の朝に目標が消えると、その日の意味づけが無くなる)。
    func testClearFinishedTargetsKeepsTargetOnTheSameInstant() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)
        _ = try repo.create(name: "今日の大会",
                            eventDate: t0,
                            entries: [CompetitionEntry(discipline: .doubles, isTarget: true)])

        try repo.clearFinishedTargets(asOf: t0)

        XCTAssertNotNil(try repo.fetchTarget(discipline: .doubles))
    }

    /// 種目ごとに独立して判定する(片方だけ終わっても、もう片方は残る)。
    func testClearFinishedTargetsIsPerDiscipline() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)
        _ = try repo.create(name: "終わったシングルス",
                            eventDate: past,
                            entries: [CompetitionEntry(discipline: .singles, isTarget: true)])
        _ = try repo.create(name: "これからのダブルス",
                            eventDate: later,
                            entries: [CompetitionEntry(discipline: .doubles, isTarget: true)])

        try repo.clearFinishedTargets(asOf: t0)

        XCTAssertNil(try repo.fetchTarget(discipline: .singles))
        XCTAssertNotNil(try repo.fetchTarget(discipline: .doubles))
    }

    // MARK: - ねらい(§7.5。目標大会でなくても持てる)

    /// 書かないのが既定。促すが強制しない(入力は原則すべて任意)。
    func testAimIsNilByDefault() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let created = try repo.create(name: "市民大会", eventDate: soon)

        XCTAssertNil(created.aim)
    }

    func testUpdateStoresAim() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)
        var competition = try repo.create(name: "市民大会", eventDate: soon)

        competition.aim = "サーブレシーブで先に攻める"
        let updated = try repo.update(competition, entries: [])

        XCTAssertEqual(updated.aim, "サーブレシーブで先に攻める")
        var reloaded: Competition = try XCTUnwrap(repo.fetch(id: competition.id))
        XCTAssertEqual(reloaded.aim, "サーブレシーブで先に攻める")
    }

    /// 消せる(空にしたら未記入に戻る)。
    func testUpdateClearsAim() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)
        var competition = try repo.create(name: "市民大会", eventDate: soon)
        competition.aim = "サーブレシーブで先に攻める"
        competition = try repo.update(competition, entries: [])

        competition.aim = nil
        let cleared = try repo.update(competition, entries: [])

        XCTAssertNil(cleared.aim)
    }

    /// 目標大会でなくてもねらいは持てる(この機能の要点)。
    func testAimWorksWithoutTargetEntry() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)
        var competition = try repo.create(name: "練習試合",
                                          eventDate: soon,
                                          entries: [CompetitionEntry(discipline: .singles, isTarget: false)])

        competition.aim = "1 ゲーム目から動く"
        let updated = try repo.update(competition, entries: [CompetitionEntry(discipline: .singles, isTarget: false)])

        XCTAssertEqual(updated.aim, "1 ゲーム目から動く")
    }
}
