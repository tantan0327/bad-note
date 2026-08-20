import Foundation
import SkipSQL

/// 設定・メタの KVS(§6 `app_meta`)。
///
/// stale の閾値と組み替え曜日、前回評価日時を持つ。閾値をロジックに埋め込まず、
/// ここから読んで渡すことで後から調整できる(§4.2)。
public struct AppMetaKey {
    private init() {
    }

    public static let staleDays = "stale_days"
    public static let stalePracticeCount = "stale_practice_count"
    public static let reshuffleWeekday = "reshuffle_weekday"
    public static let staleLastEvaluatedAt = "stale_last_evaluated_at"
}

public final class AppMetaRepository {
    private let db: SQLContext
    private let timestamps = SQLTimestamp()

    public init(db: SQLContext) {
        self.db = db
    }

    // MARK: - 素の読み書き

    public func string(forKey key: String) throws -> String? {
        let rows = try db.selectAll(sql: "SELECT value FROM app_meta WHERE key = ?", parameters: [.text(key)])
        guard let row = rows.first else {
            return nil
        }
        return row[0].textValue
    }

    public func set(_ value: String, forKey key: String) throws {
        // UPSERT は SQLite 3.24 以降。Android API 28 は 3.22 なので使わない
        try db.exec(sql: "INSERT OR REPLACE INTO app_meta (key, value) VALUES (?, ?)",
                    parameters: [.text(key), .text(value)])
    }

    public func int(forKey key: String) throws -> Int? {
        guard let text = try string(forKey: key) else {
            return nil
        }
        return Int(text)
    }

    public func setInt(_ value: Int, forKey key: String) throws {
        try set(String(value), forKey: key)
    }

    // MARK: - stale の設定

    /// 未設定なら §4.2 の初期値を返す。
    public func staleThresholds() throws -> StaleThresholds {
        let days = try int(forKey: AppMetaKey.staleDays) ?? StaleThresholds.standard.days
        let count = try int(forKey: AppMetaKey.stalePracticeCount) ?? StaleThresholds.standard.practiceCount
        return StaleThresholds(days: days, practiceCount: count)
    }

    public func setStaleThresholds(_ thresholds: StaleThresholds) throws {
        try setInt(thresholds.days, forKey: AppMetaKey.staleDays)
        try setInt(thresholds.practiceCount, forKey: AppMetaKey.stalePracticeCount)
    }

    /// 組み替えの曜日。0 = 日曜(§4.3 の既定)。
    public func reshuffleWeekday() throws -> Int {
        return try int(forKey: AppMetaKey.reshuffleWeekday) ?? 0
    }

    public func setReshuffleWeekday(_ weekday: Int) throws {
        try setInt(weekday, forKey: AppMetaKey.reshuffleWeekday)
    }

    /// 前回の評価日時。**一度も評価していなければ nil**(初期値は空文字)。
    public func staleLastEvaluatedAt() throws -> Date? {
        guard let text = try string(forKey: AppMetaKey.staleLastEvaluatedAt) else {
            return nil
        }
        if text.isEmpty {
            return nil
        }
        return timestamps.date(from: text)
    }

    public func setStaleLastEvaluatedAt(_ date: Date) throws {
        try set(timestamps.text(from: date), forKey: AppMetaKey.staleLastEvaluatedAt)
    }
}
