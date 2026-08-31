import Foundation
import SkipSQL

public enum PracticePlanRepositoryError: Error {
    /// 列の値が想定した型・値でない(スキーマと Swift 側のズレ)
    case unreadableColumn(name: String)
}

/// 練習予定日(§5.2)。`practice_plan` の永続化。
///
/// **大会までの残り練習回数は、ここに登録された日を数えて出す。**
/// 以前は練習履歴から平均間隔を割り出して推定していたが、
/// 使い始めの頻度が一生効き続けて実際とずれた。予定日は本人が決めた事実なので、
/// 数えれば実数になる。
///
/// 保存の単位は**ローカルの暦日**(`plan_date` が主キー)。
/// 同じ日は 1 行しか持てないので、まとめて追加を何度押しても増えない。
///
/// **数え上げの SQL はここに置かない。** 「今日を含む / 大会当日を含まない」といった
/// 境界規則は `PracticePlan`(純粋関数)1 か所に集める —— 2 か所に分かれると
/// 片方だけ直る事故になる。
///
/// `now` はテストからクロックを差し替えるための注入点。
public final class PracticePlanRepository {
    private let db: SQLContext
    private let now: () -> Date
    private let timestamps = SQLTimestamp()
    private let days = DayStamp()

    public init(db: SQLContext, now: @escaping () -> Date = { Date() }) {
        self.db = db
        self.now = now
    }

    // MARK: - 追加

    /// 1 日追加する。**既にあれば何もしない。**
    ///
    /// `INSERT OR IGNORE` を使うのは、先に決めた日の `created_at` を
    /// 後のまとめて追加で書き換えないため(`OR REPLACE` だと上書きされる)。
    public func add(_ date: Date) throws {
        try insert(date)
    }

    /// まとめて追加する。既にある日は増えず、`created_at` も変わらない。
    ///
    /// `add` と名前を分けているのは、オーバーロードが Skip で事故りやすいため。
    public func addAll(_ dates: [Date]) throws {
        if dates.isEmpty {
            return
        }
        try db.transaction {
            for date in dates {
                try insert(date)
            }
        }
    }

    private func insert(_ date: Date) throws {
        try db.exec(sql: "INSERT OR IGNORE INTO practice_plan (plan_date, created_at) VALUES (?, ?)",
                    parameters: [
                        SQLValue.text(days.text(from: date)),
                        SQLValue.text(timestamps.text(from: now())),
                    ])
    }

    // MARK: - 削除

    /// 1 日削除する。無ければ何もしない。
    ///
    /// **保存された文字列そのもの**で消す。`Date` から作り直すと、
    /// 端末のタイムゾーンが変わった後に別の日を消しかねない。
    public func remove(_ day: PracticePlanDay) throws {
        try db.exec(sql: "DELETE FROM practice_plan WHERE plan_date = ?",
                    parameters: [SQLValue.text(day.day)])
    }

    // MARK: - 取り出し

    /// すべての予定日。古い順。
    public func fetchAll() throws -> [PracticePlanDay] {
        let rows = try db.selectAll(sql: "SELECT plan_date, created_at FROM practice_plan ORDER BY plan_date")
        return try decodeAll(rows)
    }

    /// `asOf` の暦日以降の予定日。古い順。一覧・数え上げ・通知はこれを使う。
    ///
    /// 比較は**暦日の文字列**なので、`asOf` が朝でも夜でも同じ日を返す ——
    /// 「13 時に開いたら今日の分が落ちた」という取りこぼしが構造的に起きない。
    public func fetchUpcoming(asOf: Date) throws -> [PracticePlanDay] {
        let rows = try db.selectAll(sql: "SELECT plan_date, created_at FROM practice_plan WHERE plan_date >= ? ORDER BY plan_date",
                                    parameters: [SQLValue.text(days.text(from: asOf))])
        return try decodeAll(rows)
    }

    private func decodeAll(_ rows: [[SQLValue]]) throws -> [PracticePlanDay] {
        var result: [PracticePlanDay] = []
        for row in rows {
            result.append(try decode(row))
        }
        return result
    }

    private func decode(_ row: [SQLValue]) throws -> PracticePlanDay {
        guard let text = row.first?.textValue else {
            throw PracticePlanRepositoryError.unreadableColumn(name: "plan_date")
        }
        guard let date = days.date(from: text) else {
            throw PracticePlanRepositoryError.unreadableColumn(name: "plan_date")
        }
        return PracticePlanDay(day: text, date: date)
    }
}
