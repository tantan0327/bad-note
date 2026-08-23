import Foundation
import SkipSQL

/// 積み上げ集計の唯一の入り口(§10.3)。
///
/// 練習ログ(`practice`)と家トレ(`training_log`)を **1 回の呼び出しで合算する**。
/// 画面に出す累計はすべてここから取ること —— `PracticeRepository.totalMinutes` を
/// 直接使うと家トレの分が落ちる(あちらは「練習ログだけ」の意味で残してあり、
/// 種類別の内訳にだけ使う)。
public final class StatsRepository {
    private let practices: PracticeRepository
    private let training: TrainingRepository
    private let issues: IssueRepository

    public init(db: SQLContext) {
        self.practices = PracticeRepository(db: db)
        self.training = TrainingRepository(db: db)
        self.issues = IssueRepository(db: db)
    }

    /// 期間内の合計(分)。`from` 以上 `to` 未満(半開区間)。
    ///
    /// `practice` は UTC タイムスタンプ、家トレはローカルの暦日で比較する
    /// (家トレは日単位の記録なので、`from` / `to` の暦日に丸めて比較する)。
    /// `MonthRange` のように日の境界で切った範囲を渡す分にはずれない。
    public func totalMinutes(from: Date, to: Date) throws -> Int {
        return try practices.totalMinutes(from: from, to: to) + training.totalMinutes(from: from, to: to)
    }

    /// 通算(全期間)の合計(分)。積み上げ画面の主数字(1.2)。
    ///
    /// この数字は減らない。開くたびに必ず増えているので、そこに自信を置く。
    public func lifetimeMinutes() throws -> Int {
        return try practices.totalMinutes() + training.totalMinutes()
    }

    /// 通算のレベルアップ回数(§5.1)。上達の証。減らない数字(1.2)。
    public func lifetimeLevelUps() throws -> Int {
        return try issues.countLevelUps()
    }

    /// 定着した課題数(§7.4)。克服の証。減らない数字(1.2)。
    public func settledIssueCount() throws -> Int {
        return try issues.countArchived()
    }

    /// 月ごとの合計(分)。直近 `monthsBack` か月分を **古い順**(棒グラフは左が古い)で返す。
    ///
    /// 末尾が `asOf` を含む月。記録の無い月は 0 分の要素として入る(棒が伸びていないだけで、
    /// 「途切れ」ではない —— §5.3 の日ごとカレンダーとは違い、月の合計は減らない)。
    public func monthlyMinutes(monthsBack: Int, asOf: Date = Date(), calendar: Calendar = Calendar.current) throws -> [MonthlyMinutes] {
        let current = MonthRange.containing(asOf, calendar: calendar)
        var result: [MonthlyMinutes] = []
        var offset = monthsBack - 1
        while offset >= 0 {
            let start = calendar.date(byAdding: Calendar.Component.month, value: -offset, to: current.start) ?? current.start
            let end = calendar.date(byAdding: Calendar.Component.month, value: 1, to: start) ?? start
            result.append(MonthlyMinutes(month: start, minutes: try totalMinutes(from: start, to: end)))
            offset -= 1
        }
        return result
    }

    /// 種類ごとの合計(分・全期間)。内訳の棒グラフ(1.2)。
    ///
    /// `practice.kind` の 4 種に家トレを 1 区分足し、種類未選択は「その他」にまとめる。
    /// 合計が 0 の区分は出さない。並びは `StatsCategory` の宣言順(大きさ順にしない)。
    public func minutesByCategory() throws -> [CategoryMinutes] {
        var byCategory: [StatsCategory: Int] = [:]
        for entry in try practices.minutesByKind() {
            let category = StatsRepository.category(for: entry.kind)
            byCategory[category] = (byCategory[category] ?? 0) + entry.minutes
        }
        let home = try training.totalMinutes()
        if home > 0 {
            byCategory[.homeTraining] = (byCategory[.homeTraining] ?? 0) + home
        }

        var result: [CategoryMinutes] = []
        for category in StatsCategory.allCases {
            let minutes = byCategory[category] ?? 0
            if minutes > 0 {
                result.append(CategoryMinutes(category: category, minutes: minutes))
            }
        }
        return result
    }

    private static func category(for kind: PracticeKind?) -> StatsCategory {
        guard let kind = kind else {
            return .other
        }
        switch kind {
        case .whole: return .whole
        case .individual: return .individual
        case .game: return .game
        case .strength: return .strength
        }
    }
}
