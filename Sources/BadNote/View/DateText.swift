import Foundation

/// 日付の表示(2026-08-25)。**画面に日付を出すときは必ずここを通す。**
///
/// アプリの UI は日本語のみなので、`Date.formatted(date:time:)` のような
/// **端末のロケール任せの書式は使わない**(英語の端末で「Aug 15, 2026」と出てしまい、
/// 家トレの「8月24日(月)」と混ざる)。
///
/// 例外は **OS が描く日付ピッカー**。あれは各 OS の作法に委ねる決めごと
/// (「デザインの決めごと」のプラットフォーム差の線引き)なので、ここでは扱わない。
public struct DateText {
    private init() {
    }

    /// 「8月24日」。年が `asOf` と違えば「2025年8月24日」。
    ///
    /// 一覧やメタ情報の日付に使う。年を常に出すと冗長だが、
    /// 出さないと去年の記録が今年のものに見える。
    public static func day(_ date: Date, asOf: Date = Date()) -> String {
        return string(date, asOf: asOf, base: "M月d日")
    }

    /// 「8月24日(月)」。年が `asOf` と違えば「2027年2月20日(土)」。
    ///
    /// **その日そのものが主役の場面**に使う —— 家トレの見出し、大会の開催日。
    /// 大会は土日開催が多く、曜日が予定の判断材料になる。
    public static func dayWithWeekday(_ date: Date, asOf: Date = Date()) -> String {
        return string(date, asOf: asOf, base: "M月d日(E)")
    }

    /// 「2026年9月」。**年は常に出す。**
    ///
    /// `day` / `dayWithWeekday` は「今年なら年を省く」規則だが、これはその例外 ——
    /// カレンダー(§7.6)は何か月も先へ送れるので、年が無いと自分がどこにいるか
    /// 分からなくなる。`asOf` を取らないのはそのため。
    public static func month(_ date: Date) -> String {
        // DateFormatter は Sendable ではないので使い捨てにする
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: date)
    }

    private static func string(_ date: Date, asOf: Date, base: String) -> String {
        let calendar = Calendar.current
        let year = calendar.component(Calendar.Component.year, from: date)
        let currentYear = calendar.component(Calendar.Component.year, from: asOf)
        let format = year == currentYear ? base : "yyyy年" + base

        // DateFormatter は Sendable ではないので使い捨てにする(SQLTimestamp と同じ扱い)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}
