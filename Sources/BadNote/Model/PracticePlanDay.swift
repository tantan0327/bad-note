import Foundation

/// 練習予定日 1 日(§5.2)。
///
/// **`day` と `date` を両方持つ。** `day` は保存された文字列そのもの(`2026-09-07`)で、
/// 一覧の id と削除の手がかりに使う。`Date` から作り直して消すと、端末のタイムゾーンが
/// 変わった後に**別の日を消しかねない**。`date` はローカル暦日の 0 時で、表示と数え上げに使う。
/// 両方とも 1 行から復号するので食い違いようがない。
public struct PracticePlanDay: Hashable, Identifiable, Sendable {
    /// 保存された文字列そのもの(`2026-09-07`)
    public let day: String
    /// ローカル暦日の 0 時
    public let date: Date

    public init(day: String, date: Date) {
        self.day = day
        self.date = date
    }

    public var id: String {
        return day
    }
}
