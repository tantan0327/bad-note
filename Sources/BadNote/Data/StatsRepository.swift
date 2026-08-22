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

    public init(db: SQLContext) {
        self.practices = PracticeRepository(db: db)
        self.training = TrainingRepository(db: db)
    }

    /// 期間内の合計(分)。`from` 以上 `to` 未満(半開区間)。
    ///
    /// `practice` は UTC タイムスタンプ、家トレはローカルの暦日で比較する
    /// (家トレは日単位の記録なので、`from` / `to` の暦日に丸めて比較する)。
    /// `MonthRange` のように日の境界で切った範囲を渡す分にはずれない。
    public func totalMinutes(from: Date, to: Date) throws -> Int {
        return try practices.totalMinutes(from: from, to: to) + training.totalMinutes(from: from, to: to)
    }
}
