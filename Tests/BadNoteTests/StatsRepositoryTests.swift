import XCTest
import Foundation
import SkipSQL
@testable import BadNote

/// `StatsRepository` の仕様(§10.3)。
///
/// **積み上げ集計の唯一の入り口。** 練習ログ(`practice`)と家トレ(`training_log`)を
/// 1 回の呼び出しで合算する。`practice` はタイムスタンプ、家トレはローカルの暦日で
/// 比較する(家トレは日単位の記録)。
final class StatsRepositoryTests: XCTestCase {

    /// 2023-11-14T22:13:20Z
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

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

    func testTotalIsZeroWhenEmpty() throws {
        let db = try makeDatabase()
        defer { try? db.close() }

        XCTAssertEqual(try StatsRepository(db: db).totalMinutes(from: day(0), to: day(7)), 0)
    }

    /// 練習ログと家トレの両方を合算する(§10.3)。
    func testTotalCombinesPracticeAndTraining() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let practices = PracticeRepository(db: db)
        let training = TrainingRepository(db: db)

        _ = try practices.create(practiceDate: day(0), minutes: 90)
        let menu = try training.createMenu(name: "体幹", minutes: 10)
        _ = try training.check(menuId: menu.id, on: day(0))

        XCTAssertEqual(try StatsRepository(db: db).totalMinutes(from: day(0), to: day(1)), 100)
    }

    /// 片方だけでも成立する。
    func testTotalWithPracticeOnly() throws {
        let db = try makeDatabase()
        defer { try? db.close() }

        _ = try PracticeRepository(db: db).create(practiceDate: day(0), minutes: 60)

        XCTAssertEqual(try StatsRepository(db: db).totalMinutes(from: day(0), to: day(1)), 60)
    }

    func testTotalWithTrainingOnly() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let training = TrainingRepository(db: db)

        let menu = try training.createMenu(name: "体幹", minutes: 10)
        _ = try training.check(menuId: menu.id, on: day(0))

        XCTAssertEqual(try StatsRepository(db: db).totalMinutes(from: day(0), to: day(1)), 10)
    }

    /// 半開区間。終端の日の分は入らない(翌月の頭をそのまま渡せる)。
    func testTotalExcludesEndOfRange() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let practices = PracticeRepository(db: db)
        let training = TrainingRepository(db: db)

        let menu = try training.createMenu(name: "体幹", minutes: 10)
        // 期間内(最終日を含む)
        _ = try practices.create(practiceDate: day(6), minutes: 60)
        _ = try training.check(menuId: menu.id, on: day(6))
        // 終端の日 → 入らない
        _ = try practices.create(practiceDate: day(7, hour: 0), minutes: 45)
        _ = try training.check(menuId: menu.id, on: day(7))

        XCTAssertEqual(try StatsRepository(db: db).totalMinutes(from: day(0), to: day(7, hour: 0)), 70)
    }

    /// 今月の範囲(`MonthRange`)を渡す使い方(ホーム・保存後サマリ)。
    func testTotalWorksWithMonthRange() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let practices = PracticeRepository(db: db)
        let training = TrainingRepository(db: db)

        let month = MonthRange.containing(day(0))
        let menu = try training.createMenu(name: "体幹", minutes: 10)
        _ = try practices.create(practiceDate: day(0), minutes: 90)
        _ = try training.check(menuId: menu.id, on: day(0))
        // 範囲の外(翌月の頭)
        _ = try practices.create(practiceDate: month.end, minutes: 60)

        XCTAssertEqual(try StatsRepository(db: db).totalMinutes(from: month.start, to: month.end), 100)
    }
}
