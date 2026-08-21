import XCTest
import Foundation
import SkipSQL
@testable import BadNote

/// 設定・メタ(§6 `app_meta`)。閾値と組み替え曜日、前回評価日時を持つ KVS。
final class AppMetaRepositoryTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeDatabase() throws -> SQLContext {
        let db = SQLContext(configuration: .platform)
        try AppDatabase.prepare(db)
        return db
    }

    // MARK: - 初期値(§4.2)

    func testInitialStaleDays() throws {
        let db = try makeDatabase()
        defer { try? db.close() }

        XCTAssertEqual(21, try AppMetaRepository(db: db).staleThresholds().days)
    }

    func testInitialStalePracticeCount() throws {
        let db = try makeDatabase()
        defer { try? db.close() }

        XCTAssertEqual(6, try AppMetaRepository(db: db).staleThresholds().practiceCount)
    }

    /// 既定は日曜(0)。
    func testInitialReshuffleWeekday() throws {
        let db = try makeDatabase()
        defer { try? db.close() }

        XCTAssertEqual(0, try AppMetaRepository(db: db).reshuffleWeekday())
    }

    /// 前回評価日時は空文字で始まる = まだ一度も評価していない。
    func testInitialLastEvaluatedAtIsNil() throws {
        let db = try makeDatabase()
        defer { try? db.close() }

        XCTAssertNil(try AppMetaRepository(db: db).staleLastEvaluatedAt())
    }

    // MARK: - 読み書き

    func testSetAndGetString() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = AppMetaRepository(db: db)

        try repo.set("value", forKey: "custom")

        XCTAssertEqual("value", try repo.string(forKey: "custom"))
    }

    func testSetOverwritesExistingValue() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = AppMetaRepository(db: db)

        try repo.set("first", forKey: "custom")
        try repo.set("second", forKey: "custom")

        XCTAssertEqual("second", try repo.string(forKey: "custom"))
    }

    func testUnknownKeyReturnsNil() throws {
        let db = try makeDatabase()
        defer { try? db.close() }

        XCTAssertNil(try AppMetaRepository(db: db).string(forKey: "missing"))
    }

    /// 閾値は後から調整できる(§4.2)。
    func testThresholdsCanBeChanged() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = AppMetaRepository(db: db)

        try repo.setStaleThresholds(StaleThresholds(days: 14, practiceCount: 3))

        let thresholds = try repo.staleThresholds()
        XCTAssertEqual(14, thresholds.days)
        XCTAssertEqual(3, thresholds.practiceCount)
    }

    func testLastEvaluatedAtRoundTrip() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = AppMetaRepository(db: db)

        try repo.setStaleLastEvaluatedAt(t0)

        XCTAssertEqual(t0, try repo.staleLastEvaluatedAt())
    }

    // MARK: - めざす姿の促し(§7.1)

    func testVisionPromptIsNotShownInitially() throws {
        let db = try makeDatabase()
        defer { try? db.close() }

        XCTAssertFalse(try AppMetaRepository(db: db).isVisionPromptShown())
    }

    func testVisionPromptCanBeMarkedAsShown() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = AppMetaRepository(db: db)

        try repo.markVisionPromptShown()

        XCTAssertTrue(try repo.isVisionPromptShown())
    }
}
