import Foundation
import Observation
import SwiftUI
import SkipSQL

/// 積み上げ画面(1.2)の状態。集計は `StatsRepository` に任せ、ここは読み込みだけ。
///
/// 出すのは「合計」だけ(§5.3)。ストリーク・平均・目標値・前月比は持たない。
@Observable public final class StatsModel {
    /// 通算(全期間)の練習時間(分)。減らない数字。
    public private(set) var lifetimeMinutes = 0
    /// 月ごとの合計(分)。古い順。
    public private(set) var monthly: [MonthlyMinutes] = []
    /// 種類の内訳(分)。合計 0 の区分は入らない。
    public private(set) var categories: [CategoryMinutes] = []
    public var errorText: String? = nil

    /// 棒グラフに出す月数。スマホの幅に収まる範囲(6〜12 のうち)。
    public static let monthsBack = 6

    private var database: SQLContext? = nil

    public init() {
    }

    public func load(now: Date = Date()) {
        do {
            let stats = StatsRepository(db: try context())
            lifetimeMinutes = try stats.lifetimeMinutes()
            monthly = try stats.monthlyMinutes(monthsBack: StatsModel.monthsBack, asOf: now)
            categories = try stats.minutesByCategory()
            errorText = nil
        } catch {
            errorText = "積み上げの読み込みに失敗しました: \(error)"
        }
    }

    private func context() throws -> SQLContext {
        if let database = database {
            return database
        }
        let opened = try AppDatabase.open()
        database = opened
        return opened
    }
}

/// 積み上げ画面(1.2)。上から 通算 / 月ごと / 種類の内訳。
///
/// **見せるのは合計だけ。** ストリーク(連続日数)・日ごとのカレンダー / ヒートマップは
/// 空白が「途切れ」に見えるので出さない(§5.3)。目標値や前月比も出さない。
/// SkipUI に Swift Charts は無いので、棒は `Rectangle` / `Capsule` を自前で積む。
public struct StatsView: View {
    @State private var model = StatsModel()

    public init() {
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let errorText = model.errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                lifetimeSection
                monthlySection
                categorySection
            }
            .padding()
        }
        .navigationTitle(Text("積み上げ", bundle: .module))
        .onAppear {
            model.load()
        }
    }

    // MARK: - 1. 通算(この画面の主役。減らない数字)

    @ViewBuilder private var lifetimeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("通算", bundle: .module)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(StatsView.timeText(model.lifetimeMinutes))
                .font(.system(size: 34, weight: .semibold))
                .accessibilityIdentifier("stats-lifetime")
        }
    }

    // MARK: - 2. 月ごと(1 本ずつ伸びるのが見える)

    @ViewBuilder private var monthlySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("月ごとの時間", bundle: .module)
                .font(.headline)
            if model.monthly.isEmpty {
                emptyLine
            } else {
                Card {
                    monthlyChart
                }
            }
        }
    }

    @ViewBuilder private var monthlyChart: some View {
        let maxMinutes = StatsView.maxMinutes(model.monthly)
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(model.monthly) { entry in
                VStack(spacing: 4) {
                    // 棒。最大値に対する割合で高さを決める。0 分の月は伸びない
                    Rectangle()
                        .fill(Palette.accent)
                        .frame(height: StatsView.barHeight(entry.minutes, max: maxMinutes))
                        .cornerRadius(4)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                    Text(StatsView.monthLabel(entry.month))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 140)
        .accessibilityIdentifier("stats-monthly")
    }

    // MARK: - 3. 種類の内訳

    @ViewBuilder private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("種類の内訳", bundle: .module)
                .font(.headline)
            if model.categories.isEmpty {
                emptyLine
            } else {
                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        let maxMinutes = StatsView.maxCategoryMinutes(model.categories)
                        ForEach(model.categories) { entry in
                            categoryRow(entry, max: maxMinutes)
                        }
                    }
                }
                .accessibilityIdentifier("stats-categories")
            }
        }
    }

    @ViewBuilder private func categoryRow(_ entry: CategoryMinutes, max maxMinutes: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.category.displayName)
                    .font(.footnote)
                Spacer()
                Text(StatsView.timeText(entry.minutes))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            // 横棒。track の幅いっぱいに対する割合で fill を伸ばす
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Palette.surfaceRaised)
                    Capsule()
                        .fill(Palette.accent)
                        .frame(width: proxy.size.width * StatsView.fraction(entry.minutes, max: maxMinutes))
                }
            }
            .frame(height: 8)
        }
    }

    @ViewBuilder private var emptyLine: some View {
        // 記録が増えるのを待つだけの場所。次の 1 手は置かない(2.4)
        EmptyStateView(message: Text("まだ記録がありません", bundle: .module)) {
            EmptyView()
        }
    }

    // MARK: - 表示の計算(純粋関数)

    /// 分を「X 時間」/「Y 分」にする。60 分未満だけ分で出す。
    static func timeText(_ minutes: Int) -> String {
        if minutes >= 60 {
            return "\(minutes / 60) 時間"
        }
        return "\(minutes) 分"
    }

    /// 月ラベル(「8」)。年はまたいでも月の数字だけで足りる。
    static func monthLabel(_ month: Date) -> String {
        return "\(Calendar.current.component(Calendar.Component.month, from: month))"
    }

    private static let chartHeight = 120.0

    /// 棒の高さ。最大値に対する割合 × チャート高。0 分は 0(伸びない)。
    static func barHeight(_ minutes: Int, max maxMinutes: Int) -> Double {
        if maxMinutes <= 0 {
            return 0
        }
        return chartHeight * (Double(minutes) / Double(maxMinutes))
    }

    /// 横棒の埋まり具合(0〜1)。
    static func fraction(_ minutes: Int, max maxMinutes: Int) -> Double {
        if maxMinutes <= 0 {
            return 0
        }
        return Double(minutes) / Double(maxMinutes)
    }

    static func maxMinutes(_ entries: [MonthlyMinutes]) -> Int {
        var result = 0
        for entry in entries {
            if entry.minutes > result {
                result = entry.minutes
            }
        }
        return result
    }

    static func maxCategoryMinutes(_ entries: [CategoryMinutes]) -> Int {
        var result = 0
        for entry in entries {
            if entry.minutes > result {
                result = entry.minutes
            }
        }
        return result
    }
}
