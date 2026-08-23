import Foundation

/// 積み上げ画面(1.2)の集計に使う値。すべて `StatsRepository` が組み立てる。
///
/// 表示は「合計」だけ(§5.3)。ストリーク・平均・目標値・前月比のような
/// 解釈を伴う値はここに持たせない。

/// 種類の内訳の 1 区分。`practice.kind` の 4 種に加え、家トレと未選択(その他)。
///
/// **並びはこの宣言順を正準とする**(`allCases`)。大きさ順に並べ替えると
/// 「これが多い / 少ない」の解釈になるため、固定の順で出す。
public enum StatsCategory: String, CaseIterable, Hashable {
    case whole
    case individual
    case game
    case strength
    /// 家トレ(§10)。`practice` ではなく `training_log` 由来。
    case homeTraining
    /// 種類を選ばずに記録した練習。
    case other
}

/// 種類ごとの累計(分)。内訳の棒 1 本。
public struct CategoryMinutes: Hashable, Identifiable {
    public let category: StatsCategory
    public let minutes: Int

    public var id: String {
        return category.rawValue
    }

    public init(category: StatsCategory, minutes: Int) {
        self.category = category
        self.minutes = minutes
    }
}

/// 1 か月の累計(分)。月ごとの棒グラフの棒 1 本。
public struct MonthlyMinutes: Hashable, Identifiable {
    /// その月の頭(ローカルのカレンダー)。
    public let month: Date
    public let minutes: Int

    public var id: Date {
        return month
    }

    public init(month: Date, minutes: Int) {
        self.month = month
        self.minutes = minutes
    }
}

/// 練習ログの種類ごとの累計(分)。`PracticeRepository` の内訳集計の戻り値。
///
/// `kind` が nil の行は種類未選択(§7.2 全項目任意)。
public struct KindMinutes: Hashable {
    public let kind: PracticeKind?
    public let minutes: Int

    public init(kind: PracticeKind?, minutes: Int) {
        self.kind = kind
        self.minutes = minutes
    }
}
