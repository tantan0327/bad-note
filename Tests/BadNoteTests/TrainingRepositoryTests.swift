import XCTest
import Foundation
import SkipSQL
@testable import BadNote

/// `TrainingRepository` の仕様(§10)。
///
/// - メニューは削除せずアーカイブする。実施記録を守るため
/// - チェックはその日 × メニューで 1 行。付け直しても増えない
/// - **チェック時点の分数を写して固定する。** 後からメニューの目安を直しても
///   過去の実施記録は変わらない(§10.3)
/// - 集計は日単位の半開区間。`training_date` はローカルの暦日
/// - DB はテストごとに新規のインメモリ(`SQLContext(configuration: .platform)`)
final class TrainingRepositoryTests: XCTestCase {

    /// 2023-11-14T22:13:20Z
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private var clock = Date(timeIntervalSince1970: 1_700_000_000)

    /// t0 を含むローカルの暦日の 0 時。日付の計算はここを起点にする。
    private var day0: Date {
        return Calendar.current.startOfDay(for: t0)
    }

    private func day(_ offset: Int, hour: Int = 12) -> Date {
        let calendar = Calendar.current
        let base = calendar.date(byAdding: .day, value: offset, to: day0) ?? day0
        return calendar.date(byAdding: .hour, value: hour, to: base) ?? base
    }

    private func makeDatabase() throws -> SQLContext {
        let db = SQLContext(configuration: .platform)
        try AppDatabase.prepare(db)
        return db
    }

    private func makeRepository(_ db: SQLContext) -> TrainingRepository {
        clock = t0
        return TrainingRepository(db: db, now: { self.clock })
    }

    // MARK: - メニュー

    func testCreateMenuStoresNameAndMinutes() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let menu = try repo.createMenu(name: "体幹", minutes: 10)

        XCTAssertEqual(menu.name, "体幹")
        XCTAssertEqual(menu.minutes, 10)
        XCTAssertFalse(menu.isArchived)
    }

    /// 目安の分数は任意(§10.1)。
    func testCreateMenuAllowsNilMinutes() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let menu = try repo.createMenu(name: "素振り 50 回")

        XCTAssertNil(menu.minutes)
    }

    /// 追加した順に並ぶ(sort_order を末尾に足す)。
    func testMenusKeepCreationOrder() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        _ = try repo.createMenu(name: "素振り")
        _ = try repo.createMenu(name: "体幹")
        _ = try repo.createMenu(name: "ランニング")

        let names = try repo.fetchMenus().map { $0.name }
        XCTAssertEqual(names, ["素振り", "体幹", "ランニング"])
    }

    func testUpdateMenuChangesNameAndMinutes() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        var menu = try repo.createMenu(name: "体幹", minutes: 10)
        menu.name = "体幹トレーニング"
        menu.minutes = 30
        let updated = try repo.updateMenu(menu)

        XCTAssertEqual(updated.name, "体幹トレーニング")
        XCTAssertEqual(updated.minutes, 30)
    }

    /// アーカイブで一覧から消える。行は消さない(§10.2)。
    func testArchivedMenuIsHiddenButNotDeleted() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let menu = try repo.createMenu(name: "体幹", minutes: 10)
        _ = try repo.createMenu(name: "素振り")
        try repo.archiveMenu(id: menu.id)

        let visible = try repo.fetchMenus().map { $0.name }
        XCTAssertEqual(visible, ["素振り"])
        let all = try repo.fetchMenus(includeArchived: true).map { $0.name }
        XCTAssertEqual(all.count, 2)
    }

    /// 並び替えは渡した順で sort_order を振り直す。
    func testReorderMenus() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let a = try repo.createMenu(name: "素振り")
        let b = try repo.createMenu(name: "体幹")
        let c = try repo.createMenu(name: "ランニング")

        try repo.reorderMenus(ids: [c.id, a.id, b.id])

        let names = try repo.fetchMenus().map { $0.name }
        XCTAssertEqual(names, ["ランニング", "素振り", "体幹"])
    }

    // MARK: - チェック

    func testCheckCreatesLogForThatDay() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let menu = try repo.createMenu(name: "体幹", minutes: 10)
        _ = try repo.check(menuId: menu.id, on: day(0))

        let logs = try repo.fetchLogs(on: day(0))
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.menuId, menu.id)
        XCTAssertNotNil(logs.first?.doneAt)
    }

    /// 同じ日に 2 回チェックしても 1 行のまま(UNIQUE)。
    func testCheckTwiceKeepsSingleRow() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let menu = try repo.createMenu(name: "体幹", minutes: 10)
        _ = try repo.check(menuId: menu.id, on: day(0))
        _ = try repo.check(menuId: menu.id, on: day(0))

        let logs = try repo.fetchLogs(on: day(0))
        XCTAssertEqual(logs.count, 1)
    }

    /// チェックはその日単位。同じ日の別時刻でも同じ日として扱う。
    func testCheckIsKeyedByLocalDay() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let menu = try repo.createMenu(name: "体幹", minutes: 10)
        _ = try repo.check(menuId: menu.id, on: day(0, hour: 8))
        _ = try repo.check(menuId: menu.id, on: day(0, hour: 21))

        XCTAssertEqual(try repo.fetchLogs(on: day(0)).count, 1)
        XCTAssertEqual(try repo.fetchLogs(on: day(1)).count, 0)
    }

    /// 押し間違いは必ず起きる。チェックは外せる(§10.2)。
    func testUncheckRemovesLog() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let menu = try repo.createMenu(name: "体幹", minutes: 10)
        _ = try repo.check(menuId: menu.id, on: day(0))
        try repo.uncheck(menuId: menu.id, on: day(0))

        XCTAssertEqual(try repo.fetchLogs(on: day(0)).count, 0)
        XCTAssertEqual(try repo.totalMinutes(from: day(0), to: day(1)), 0)
    }

    /// 昨日以前もさかのぼって付けられる(§10.2)。
    func testCheckOnPastDay() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let menu = try repo.createMenu(name: "体幹", minutes: 10)
        _ = try repo.check(menuId: menu.id, on: day(-1))

        XCTAssertEqual(try repo.fetchLogs(on: day(-1)).count, 1)
        XCTAssertEqual(try repo.fetchLogs(on: day(0)).count, 0)
    }

    // MARK: - 分数の固定(§10.3)

    /// チェック時点の分数を写す。
    func testCheckCopiesMinutesFromMenu() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let menu = try repo.createMenu(name: "体幹", minutes: 10)
        let log = try repo.check(menuId: menu.id, on: day(0))

        XCTAssertEqual(log.minutes, 10)
    }

    /// **後からメニューの目安を直しても、過去の実施記録は変わらない。**
    func testEditingMenuMinutesDoesNotRewriteHistory() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        var menu = try repo.createMenu(name: "体幹", minutes: 10)
        _ = try repo.check(menuId: menu.id, on: day(-1))

        menu.minutes = 30
        _ = try repo.updateMenu(menu)
        _ = try repo.check(menuId: menu.id, on: day(0))

        XCTAssertEqual(try repo.totalMinutes(from: day(-1), to: day(0)), 10)
        XCTAssertEqual(try repo.totalMinutes(from: day(0), to: day(1)), 30)
    }

    /// 分数の無いメニューは 0 分として積み上げに入る(§10.3)。
    func testNilMinutesCountsAsZero() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let named = try repo.createMenu(name: "体幹", minutes: 10)
        let unnamed = try repo.createMenu(name: "素振り 50 回")
        _ = try repo.check(menuId: named.id, on: day(0))
        _ = try repo.check(menuId: unnamed.id, on: day(0))

        XCTAssertEqual(try repo.totalMinutes(from: day(0), to: day(1)), 10)
    }

    // MARK: - 集計(日単位の半開区間)

    func testTotalMinutesUsesHalfOpenDayRange() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let menu = try repo.createMenu(name: "体幹", minutes: 10)
        _ = try repo.check(menuId: menu.id, on: day(0))
        _ = try repo.check(menuId: menu.id, on: day(1))
        _ = try repo.check(menuId: menu.id, on: day(2))

        // day(0) 以上 day(2) 未満 → day(0) と day(1) の 2 件
        XCTAssertEqual(try repo.totalMinutes(from: day(0), to: day(2)), 20)
    }

    /// アーカイブは戻せる(3.5)。戻しても実施記録と分数はそのまま。
    func testUnarchiveRestoresMenuWithHistory() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let menu = try repo.createMenu(name: "体幹", minutes: 10)
        _ = try repo.check(menuId: menu.id, on: day(0))
        try repo.archiveMenu(id: menu.id)
        XCTAssertEqual(0, try repo.fetchMenus().count)

        var restored: TrainingMenu = try XCTUnwrap(repo.fetchMenus(includeArchived: true).first)
        restored.isArchived = false
        _ = try repo.updateMenu(restored)

        let names = try repo.fetchMenus().map { $0.name }
        XCTAssertEqual(names, ["体幹"])
        XCTAssertEqual(try repo.totalMinutes(from: day(0), to: day(1)), 10)
    }

    /// アーカイブしても過去の実施記録は集計に残る。
    func testArchivedMenuKeepsPastLogsInTotal() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let menu = try repo.createMenu(name: "体幹", minutes: 10)
        _ = try repo.check(menuId: menu.id, on: day(0))
        try repo.archiveMenu(id: menu.id)

        XCTAssertEqual(try repo.totalMinutes(from: day(0), to: day(1)), 10)
    }
}
