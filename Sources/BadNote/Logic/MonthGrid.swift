import Foundation

/// カレンダーの 1 マス(§7.6)。
public struct MonthGridDay: Hashable, Sendable {
    /// ローカル暦日の 0 時
    public let date: Date
    /// 画面に出す数字(1〜31)
    public let dayNumber: Int
    /// 表示している月の日か。**false = 前後の月**(淡く出して押せない)
    public let isInMonth: Bool

    public init(date: Date, dayNumber: Int, isInMonth: Bool) {
        self.date = date
        self.dayNumber = dayNumber
        self.isInMonth = isInMonth
    }
}

/// 月カレンダーの升目(§7.6)。純粋関数。DB も現在時刻も見ない。
///
/// **常にちょうど 42 個(6 週 × 7 日)を返し、先頭は必ず日曜。**
///
/// - 42 固定なのは、View を定数レンジ(`ForEach(0..<6)` / `ForEach(0..<7)`)で回せて、
///   月を送ってもカレンダーの高さが跳ねないため。
///   31 日 × 土曜始まり(2026-08)でも 6 + 31 = 37 なので必ず収まる
/// - **前後の月の日で埋める**(空白にしない)。2026-02 は日曜始まりの 28 日なので、
///   空白にすると下 2 行が丸ごと空いて壊れて見える
/// - **端末の暦の `firstWeekday` に従わない。** 従うと en-GB の端末で月曜始まりになり、
///   曜日の見出し(`WeekdayName.of`、0 = 日曜)と 1 日ずれる
public struct MonthGrid {
    private init() {
    }

    public static let weekCount = 6
    public static let dayCount = 7
    public static let cellCount = 42

    /// その月を含む 1 画面ぶん。**常に 42 個、先頭は日曜。**
    public static func cells(of month: Date, calendar: Calendar = Calendar.current) -> [MonthGridDay] {
        // 月頭への丸めは既存の純粋関数に任せる(同じものを 2 つ作らない)
        let monthStart = MonthRange.containing(month, calendar: calendar).start
        // Calendar の weekday は 1 = 日曜。日曜始まりに揃えるので 1 を引く
        let offset = calendar.component(Calendar.Component.weekday, from: monthStart) - 1

        var result: [MonthGridDay] = []
        for index in 0..<MonthGrid.cellCount {
            guard let day = calendar.date(byAdding: Calendar.Component.day,
                                          value: index - offset,
                                          to: monthStart) else {
                // ここに来ると 42 個に満たず View が範囲外で落ちる。
                // 起きない前提だが、落ちるより手前で止める
                return result
            }
            let start = calendar.startOfDay(for: day)
            result.append(MonthGridDay(date: start,
                                       dayNumber: calendar.component(Calendar.Component.day, from: start),
                                       isInMonth: MonthRange.containing(start, calendar: calendar).start == monthStart))
        }
        return result
    }

    /// 表示中の月を月単位で送る。返るのは**その月の 1 日 0 時**。
    ///
    /// 月頭に丸めてから足すので、1 月 31 日から 1 か月進めても 3 月に飛ばない。
    public static func shifted(_ month: Date, by months: Int, calendar: Calendar = Calendar.current) -> Date {
        let monthStart = MonthRange.containing(month, calendar: calendar).start
        guard let shifted = calendar.date(byAdding: Calendar.Component.month, value: months, to: monthStart) else {
            return monthStart
        }
        return shifted
    }
}
