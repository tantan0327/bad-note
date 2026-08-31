import Foundation

/// 画面に出す名前を 1 か所にまとめる。
///
/// 同じラベルが複数の画面に出るため、文言を変えるときに取りこぼさないようにする。

extension MasteryLevel {
    /// §3.2 の 4 段階。
    ///
    /// **「素振り」ではなく「素振りでできる」。** 名詞のままだと練習ログの「種類」
    /// (全体練習 / 個人練習 / ゲーム練習 / 筋トレ)と語彙が衝突して、
    /// 「その練習をやった」の意味に読めてしまう。ここで表すのは到達している段階。
    public var displayName: String {
        switch self {
        case .solo: return "素振りでできる"
        case .drill: return "ノックでできる"
        case .pattern: return "パターン練習でできる"
        case .match: return "試合で出せる"
        }
    }
}

extension FocusResult {
    /// §3 手応え 3 段階。「×」「失敗」「未達」に当たる語は出さない。
    public var displayName: String {
        switch self {
        case .done: return "できた"
        case .closer: return "近づいた"
        case .next: return "次にやる"
        }
    }
}

extension Discipline {
    public var displayName: String {
        switch self {
        case .singles: return "シングルス"
        case .doubles: return "ダブルス"
        case .both: return "両方"
        }
    }
}

extension PracticeKind {
    /// §7.2 練習の種類。習熟度とは別物。
    public var displayName: String {
        switch self {
        case .whole: return "全体練習"
        case .individual: return "個人練習"
        case .game: return "ゲーム練習"
        case .strength: return "筋トレ"
        }
    }
}

extension StatsCategory {
    /// 積み上げの内訳(1.2)。練習の種類と揃える。
    public var displayName: String {
        switch self {
        case .whole: return "全体練習"
        case .individual: return "個人練習"
        case .game: return "ゲーム練習"
        case .strength: return "筋トレ"
        case .homeTraining: return "家トレ"
        case .other: return "その他"
        }
    }
}

extension StaleReason {
    /// §4.3 の理由文。アプリは解釈や警告を出さず、事実だけを添える。
    public var displayName: String {
        switch self {
        case .neverFocused: return "一度も重点に入っていません"
        case .leftFocus: return "重点から外れたあと、触れていません"
        case .noUpdate: return "しばらく更新がありません"
        }
    }
}

/// 影響度と習得コスト(§3.4)。
///
/// **数字は画面に出さない。** 1 と 3 のどちらが大きいのか画面から読み取れず、
/// 入力する側が迷う。DB は 1〜3 のまま持ち、表示だけ言葉にする。
public struct ScaleLabel {
    private init() {
    }

    /// 取り得る値。1 が小さく 3 が大きい。
    public static let values = [1, 2, 3]

    /// 影響度 — 試合の失点に直結するか。
    public static func impact(_ value: Int) -> String {
        switch value {
        case 1: return "小さい"
        case 2: return "中くらい"
        default: return "大きい"
        }
    }

    /// 習得コスト — 直るまでの時間。3 はシーズン単位(§3.4)。
    public static func cost(_ value: Int) -> String {
        switch value {
        case 1: return "すぐ直る"
        case 2: return "少しかかる"
        default: return "シーズン単位"
        }
    }

}

/// 曜日の 1 文字。**0 = 日曜 ... 6 = 土曜**
/// (`reshuffle_weekday` と練習予定日の生成で使う番号体系)。
///
/// アプリで唯一の「曜日の番号 → 日本語」の変換表。通知設定と
/// 練習予定日のまとめて追加の 2 か所から参照する。
/// 日付の中に曜日を出す場合は `DateText.dayWithWeekday(_:)` を使うこと
/// (あちらは暦から曜日を出すので、この表とは役割が違う)。
public struct WeekdayName {
    private init() {
    }

    public static func of(_ value: Int) -> String {
        switch value {
        case 0: return "日"
        case 1: return "月"
        case 2: return "火"
        case 3: return "水"
        case 4: return "木"
        case 5: return "金"
        default: return "土"
        }
    }
}
