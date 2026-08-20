import Foundation

/// 1 か月の範囲。`start` 以上 `end` 未満(半開区間)。
///
/// §7.2 の保存後に出す「今月の累計」の集計期間に使う。
/// 月の区切りはユーザーのカレンダー(ローカルタイムゾーン)で決める。
/// DB は UTC の ISO 8601 で保存しているが、比較するのは同じ時点を指す `Date` 同士なので
/// タイムゾーンによるずれは起きない。
public struct MonthRange: Hashable {
    public let start: Date
    /// 翌月の頭。**この時刻は含まない。**
    public let end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }

    public static func containing(_ date: Date, calendar: Calendar = Calendar.current) -> MonthRange {
        let components = calendar.dateComponents([Calendar.Component.year, Calendar.Component.month], from: date)
        let start = calendar.date(from: components) ?? date
        let end = calendar.date(byAdding: Calendar.Component.month, value: 1, to: start) ?? start
        return MonthRange(start: start, end: end)
    }
}
