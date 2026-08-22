import Foundation

/// 家トレの日付の保存形式(§10.4)。
///
/// 「その日やったか」の単位は**ローカルの暦日**なので、タイムスタンプではなく
/// `2026-08-22` 形式の TEXT で保存する。`practice_date`(UTC の ISO 8601)とは
/// 形式が違うことに注意。この形なら辞書順比較 = 日付順比較が成り立つ。
final class DayStamp {
    private let formatter: DateFormatter

    init() {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        self.formatter = formatter
    }

    /// 例: `2026-08-22`(ローカルタイムゾーンの暦日)
    func text(from date: Date) -> String {
        return formatter.string(from: date)
    }
}
