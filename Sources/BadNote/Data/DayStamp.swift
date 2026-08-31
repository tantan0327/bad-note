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

    /// 保存された文字列から**ローカル暦日の 0 時**に戻す。読めなければ nil。
    ///
    /// 練習予定日(§5.2)は保存文字列そのものを id にして削除するので、
    /// 往復が崩れると消せなくなる。**壊れた行を「今日」に丸めない**ために
    /// 既定値を返さず nil を返す。
    ///
    /// **書き戻して一致するかで確かめている。** Android の `DateFormatter` は寛容で、
    /// `2026-13-45` を nil にせず 2027-02-14 に**繰り上げて受け入れる**(iOS は nil)。
    /// 繰り上げや桁落ちがあれば書き戻した文字列が変わるので、この形なら
    /// 両プラットフォームで同じ判定になる。ゼロ埋めしていない `2026-3-1` も弾ける。
    func date(from text: String) -> Date? {
        guard let date = formatter.date(from: text) else {
            return nil
        }
        if formatter.string(from: date) != text {
            return nil
        }
        return date
    }
}
