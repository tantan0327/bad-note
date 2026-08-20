import Foundation

/// タイムスタンプの保存形式。
///
/// **UTC の ISO 8601(秒精度)TEXT で統一する**(§4.2)。この形なら
/// `julianday()` でも辞書順比較でも前後を判定でき、`practice_date > left_at` がずれない。
///
/// `ISO8601DateFormatter` は Sendable ではないので static では持たず、
/// Repository ごとにインスタンスを 1 つ持つ。
final class SQLTimestamp {
    private let formatter: ISO8601DateFormatter

    init() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = .withInternetDateTime
        formatter.timeZone = TimeZone(identifier: "UTC")
        self.formatter = formatter
    }

    /// 例: `2023-11-14T22:13:20Z`
    func text(from date: Date) -> String {
        formatter.string(from: date)
    }

    func date(from text: String) -> Date? {
        formatter.date(from: text)
    }
}
