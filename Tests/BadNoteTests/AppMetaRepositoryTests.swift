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

    // MARK: - 通知設定(§8)

    /// 既定は off。許可を求める前に勝手に鳴らさない。
    func testNotificationsAreDisabledByDefault() throws {
        let db = try makeDatabase()
        defer { try? db.close() }

        XCTAssertFalse(try AppMetaRepository(db: db).notificationSettings().isEnabled)
    }

    /// 通知時刻は分まで保存する(2.5)。既存の DB(キー無し)では 0 分。
    func testNotificationTimeMinutesRoundTrip() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = AppMetaRepository(db: db)

        XCTAssertEqual(0, try repo.notificationSettings().practiceMinute)
        XCTAssertEqual(0, try repo.notificationSettings().eveningMinute)

        try repo.setNotificationSettings(NotificationSettings(isEnabled: true,
                                                              practiceWeekdays: [1],
                                                              practiceHour: 18,
                                                              practiceMinute: 30,
                                                              eveningHour: 20,
                                                              eveningMinute: 45,
                                                              reshuffleWeekday: 0))

        let loaded = try repo.notificationSettings()
        XCTAssertEqual(30, loaded.practiceMinute)
        XCTAssertEqual(45, loaded.eveningMinute)
    }

    func testNotificationSettingsRoundTrip() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = AppMetaRepository(db: db)

        try repo.setNotificationSettings(NotificationSettings(isEnabled: true,
                                                              practiceWeekdays: [2, 4],
                                                              practiceHour: 17,
                                                              eveningHour: 21,
                                                              reshuffleWeekday: 0))

        let settings = try repo.notificationSettings()
        XCTAssertTrue(settings.isEnabled)
        XCTAssertEqual([2, 4], settings.practiceWeekdays)
        XCTAssertEqual(17, settings.practiceHour)
        XCTAssertEqual(21, settings.eveningHour)
    }

    /// 組み替えの曜日は §4.3 の設定と同じものを見る。二重に持たない。
    func testNotificationSettingsShareReshuffleWeekday() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = AppMetaRepository(db: db)

        try repo.setReshuffleWeekday(3)

        XCTAssertEqual(3, try repo.notificationSettings().reshuffleWeekday)
    }

    func testPracticeWeekdaysCanBeCleared() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = AppMetaRepository(db: db)

        try repo.setNotificationSettings(NotificationSettings(isEnabled: true, practiceWeekdays: [1]))
        try repo.setNotificationSettings(NotificationSettings(isEnabled: true, practiceWeekdays: []))

        XCTAssertEqual(0, try repo.notificationSettings().practiceWeekdays.count)
    }
}
