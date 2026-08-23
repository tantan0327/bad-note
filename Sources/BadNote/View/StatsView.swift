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
    /// 通算のレベルアップ回数(上達の証)。減らない数字。
    public private(set) var lifetimeLevelUps = 0
    /// 定着した課題数(克服の証)。減らない数字。
    public private(set) var settledCount = 0
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
            lifetimeLevelUps = try stats.lifetimeLevelUps()
            settledCount = try stats.settledIssueCount()
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
    /// カウントアップで表示中の通算(分)。0 から実値へ伸ばす。
    @State private var shownMinutes = 0
    /// 主役パネルの登場アニメーション。
    @State private var appeared = false

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
        // .task は表示時にメインアクターで走る(SkipUI 対応)。読み込み → カウントアップ
        .task {
            model.load()
            appeared = true
            await animateLifetime()
        }
    }

    // MARK: - 1. 通算(この画面の主役。減らない数字)

    /// 開くたびに増えている数字を、主役として大きく・温かく出す。
    /// 通算の時間に加え、上達(レベルアップ)と克服(定着)も並べる(CLAUDE.md 積み上げ側の数字)。
    @ViewBuilder private var lifetimeSection: some View {
        Card(background: Palette.surfaceRaised) {
            VStack(spacing: 12) {
                Image("emoji_events", bundle: .module)
                    .font(.largeTitle)
                    .foregroundStyle(Palette.accent)
                Text("ここまで積み上げた時間", bundle: .module)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                // 分まで出す。1 回の練習で必ず桁が動く(開くたびに増えて見える)
                Text(StatsView.heroTimeText(shownMinutes))
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("stats-lifetime")
                secondaryStats
            }
            .frame(maxWidth: .infinity)
        }
        .opacity(appeared ? 1.0 : 0.0)
        .scaleEffect(appeared ? 1.0 : 0.97)
        .animation(.easeOut(duration: 0.35), value: appeared)
    }

    /// 上達と克服。時間だけでなく「上手くなった / 乗り越えた」を出して自信につなげる。
    @ViewBuilder private var secondaryStats: some View {
        HStack(spacing: 12) {
            statItem(value: model.lifetimeLevelUps,
                     unit: Text("回", bundle: .module),
                     label: Text("レベルアップ", bundle: .module))
            statItem(value: model.settledCount,
                     unit: Text("件", bundle: .module),
                     label: Text("定着した課題", bundle: .module))
        }
        .padding(.top, 4)
    }

    @ViewBuilder private func statItem(value: Int, unit: Text, label: Text) -> some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(verbatim: "\(value)")
                    .font(.system(size: 22, weight: .semibold))
                unit
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            label
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    /// 通算を 0 から実値へ伸ばす。約 0.5 秒。数字が動いて量感が伝わる。
    private func animateLifetime() async {
        let target = model.lifetimeMinutes
        if target <= 0 {
            shownMinutes = 0
            return
        }
        let steps = 24
        var step = 1
        while step <= steps {
            shownMinutes = target * step / steps
            try? await Task.sleep(nanoseconds: 20_000_000) // 20ms × 24 ≒ 0.5 秒
            step += 1
        }
        shownMinutes = target
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

    /// 主役の通算。**分まで**出して、1 回の練習で必ず桁が動くようにする。
    /// 「12時間30分」/「3時間」/「45分」。
    static func heroTimeText(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 && mins > 0 {
            return "\(hours)時間\(mins)分"
        }
        if hours > 0 {
            return "\(hours)時間"
        }
        return "\(mins)分"
    }

    /// 分を「X 時間」/「Y 分」にする。60 分未満だけ分で出す(内訳・月ごと用)。
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
