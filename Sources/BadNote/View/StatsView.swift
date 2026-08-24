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
        // 共有接続(6.3)。モデルごとに開くと database is locked を踏む
        return try AppDatabase.shared()
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
                milestoneSection
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
    /// 数字の形は課題詳細の「記録」と共通(`StatItem`。tasks.md 2.2)。
    @ViewBuilder private var secondaryStats: some View {
        HStack(spacing: 12) {
            StatItem(value: model.lifetimeLevelUps,
                     unit: Text("回", bundle: .module),
                     label: Text("レベルアップ", bundle: .module))
            StatItem(value: model.settledCount,
                     unit: Text("件", bundle: .module),
                     label: Text("定着した課題", bundle: .module))
        }
        .padding(.top, 4)
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

    // MARK: - 2. 節目(達成の記録 + 次の 1 段。§5.3 残り時間・締め切りは出さない)

    /// 達成済みチップの先に**次の節目**を輪郭チップで置き、そこまでの進み具合を
    /// バーの満ち具合だけで見せる(2026-08-24。1 万時間だけが遠くに見える対策)。
    /// 「あと N 時間」の文言は出さない(§5.3)。1 万時間は階段の最終段で、
    /// 画面には脚注 1 行として触れるだけ。通算 0 のときは丸ごと隠す
    /// (最初の記録がこのセクションの初登場 = 最初のご褒美)。
    @ViewBuilder private var milestoneSection: some View {
        let reached = Milestone.reachedHours(minutes: model.lifetimeMinutes)
        let next = Milestone.nextHours(minutes: model.lifetimeMinutes)
        if model.lifetimeMinutes > 0 {
            VStack(alignment: .leading, spacing: 8) {
                Text("節目", bundle: .module)
                    .font(.headline)
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(reached, id: \.self) { hours in
                            milestoneBadge(hours, isLatest: hours == reached[reached.count - 1])
                        }
                        if let nextHours = next {
                            nextBadge(nextHours)
                        }
                    }
                }
                if next != nil {
                    progressRow(progress: Milestone.progressToNext(minutes: model.lifetimeMinutes))
                    Text("この階段は 1 万時間(1 万時間の法則)まで続きます", bundle: .module)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    // 最終段まで登り切った
                    Text("1 万時間にとどきました", bundle: .module)
                        .font(.caption)
                        .foregroundStyle(Palette.accent)
                }
            }
            .accessibilityIdentifier("stats-milestones")
        }
    }

    /// 節目のチップ。直近に届いたものだけ accent で強調する。
    @ViewBuilder private func milestoneBadge(_ hours: Int, isLatest: Bool) -> some View {
        Text(verbatim: "\(hours)時間")
            .font(.caption)
            .foregroundStyle(isLatest ? Color.white : Color.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isLatest ? Palette.accent : Palette.surfaceRaised)
            .cornerRadius(4)
            .accessibilityLabel(Text(verbatim: "\(hours)時間 達成"))
    }

    /// 次の節目のチップ。まだ先なので**枠線だけ**(埋めない)。
    @ViewBuilder private func nextBadge(_ hours: Int) -> some View {
        Text(verbatim: "\(hours)時間")
            .font(.caption)
            .foregroundStyle(Palette.accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Palette.accent, lineWidth: 1)
            )
            .accessibilityLabel(Text(verbatim: "次の節目 \(hours)時間"))
    }

    /// 次の節目までの進み具合。**満ちていく側だけ**を見せ、数字は出さない(§5.3)。
    /// 見た目の「数字なし」は演出なので、VoiceOver にだけ割合を伝える。
    @ViewBuilder private func progressRow(progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("次の節目まで", bundle: .module)
                .font(.caption)
                .foregroundStyle(.secondary)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Palette.surfaceRaised)
                    Capsule()
                        .fill(Palette.accent)
                        .frame(width: StatsView.progressWidth(total: proxy.size.width,
                                                             progress: appeared ? progress : 0.0))
                }
            }
            .frame(height: 8)
            // 主役パネルの登場と同じ流儀で 0 → 実値へ満ちる
            .animation(.easeOut(duration: 0.35), value: appeared)
        }
        .accessibilityLabel(Text("次の節目まで", bundle: .module))
        .accessibilityValue(Text(verbatim: "\(Int(progress * 100))%"))
        .accessibilityIdentifier("stats-milestone-progress")
    }

    // MARK: - 3. 月ごと(1 本ずつ伸びるのが見える)

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
        let lastIndex = model.monthly.count - 1
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(0..<model.monthly.count, id: \.self) { index in
                // 年の変わり目(1 月)と左端は年を添える —— 「8」だけだと年またぎが分からない(⑤)
                monthColumn(model.monthly[index],
                            isCurrent: index == lastIndex,
                            showYear: index == 0 || StatsView.isJanuary(model.monthly[index].month),
                            max: maxMinutes)
            }
        }
        .frame(height: 176)
        .accessibilityIdentifier("stats-monthly")
    }

    @ViewBuilder private func monthColumn(_ entry: MonthlyMinutes, isCurrent: Bool, showYear: Bool, max maxMinutes: Int) -> some View {
        VStack(spacing: 4) {
            // 今月だけ値を上に出す。短い棒でも「途中」だと伝わり、下降に見えない(④)
            Text(verbatim: isCurrent && entry.minutes > 0 ? StatsView.timeText(entry.minutes) : " ")
                .font(.caption)
                .foregroundStyle(Palette.accent)
                .frame(height: 16)
            // 0 分の月も薄いスリバーで残す —— 空白の列は「途切れ」に見えるため(§5.3)
            Rectangle()
                .fill(StatsView.barColor(minutes: entry.minutes, isCurrent: isCurrent))
                .frame(height: StatsView.monthBarHeight(entry.minutes, max: maxMinutes))
                .cornerRadius(4)
                .frame(maxHeight: .infinity, alignment: .bottom)
            // 月ラベル(2 行分を確保して棒の底を揃える)。今月は数字でなく「今月」
            VStack(spacing: 1) {
                monthLabel(entry, isCurrent: isCurrent)
                    .font(.caption)
                    .foregroundStyle(isCurrent ? Palette.accent : Color.secondary)
                Text(verbatim: showYear && !isCurrent ? StatsView.yearLabel(entry.month) : " ")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .frame(height: 28)
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel(Text(verbatim: "\(StatsView.yearLabel(entry.month)) \(StatsView.monthLabel(entry.month))月 \(StatsView.timeText(entry.minutes))"))
    }

    private func monthLabel(_ entry: MonthlyMinutes, isCurrent: Bool) -> Text {
        if isCurrent {
            return Text("今月", bundle: .module)
        }
        return Text(verbatim: StatsView.monthLabel(entry.month))
    }

    // MARK: - 4. 種類の内訳

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
            // 横棒。track の幅に対する割合で fill を伸ばす。カテゴリごとに accent の濃さを変える
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Palette.surfaceRaised)
                    Capsule()
                        .fill(Palette.accent.opacity(StatsView.categoryOpacity(entry.category)))
                        // 記録のあるカテゴリは最小幅を保証して、小さくても必ず見えるようにする(⑥)
                        .frame(width: StatsView.barWidth(entry.minutes, max: maxMinutes, track: proxy.size.width))
                }
            }
            .frame(height: 8)
        }
        .accessibilityLabel(Text(verbatim: "\(entry.category.displayName) \(StatsView.timeText(entry.minutes))"))
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

    /// 月ラベル(「8」)。年の情報は `yearLabel` で別に添える(⑤)。
    static func monthLabel(_ month: Date) -> String {
        return "\(Calendar.current.component(Calendar.Component.month, from: month))"
    }

    /// その月が 1 月か(年の変わり目の判定に使う)。
    static func isJanuary(_ month: Date) -> Bool {
        return Calendar.current.component(Calendar.Component.month, from: month) == 1
    }

    /// 年ラベル(「'26」)。年の変わり目と左端にだけ添える(⑤)。
    static func yearLabel(_ month: Date) -> String {
        let year = Calendar.current.component(Calendar.Component.year, from: month) % 100
        if year < 10 {
            return "'0\(year)"
        }
        return "'\(year)"
    }

    private static let chartHeight = 120.0

    /// 棒の高さ。最大値に対する割合 × チャート高。0 分は 0(伸びない)。
    static func barHeight(_ minutes: Int, max maxMinutes: Int) -> Double {
        if maxMinutes <= 0 {
            return 0
        }
        return chartHeight * (Double(minutes) / Double(maxMinutes))
    }

    /// 節目の進捗バーの塗り幅。0 は 0 のまま、少しでも進んでいれば最低 4pt を
    /// 保証して「登り始めた」ことが見えるようにする(月グラフの最低 6pt と同じ考え方)。
    static func progressWidth(total: CGFloat, progress: Double) -> CGFloat {
        if progress <= 0.0 {
            return 0.0
        }
        let width = total * CGFloat(progress)
        return width < 4.0 ? 4.0 : width
    }

    /// 月グラフの棒の高さ。0 分は薄いスリバー(3pt)、それ以外は最低 6pt を保証して
    /// 記録のある月が必ず見えるようにする(④)。
    static func monthBarHeight(_ minutes: Int, max maxMinutes: Int) -> Double {
        if minutes <= 0 {
            return 3.0
        }
        let height = barHeight(minutes, max: maxMinutes)
        return height < 6.0 ? 6.0 : height
    }

    /// 月グラフの棒の色。0 分は面の色(空だと分かる)、今月は accent、過去は薄い accent(④)。
    static func barColor(minutes: Int, isCurrent: Bool) -> Color {
        if minutes <= 0 {
            return Palette.surfaceRaised
        }
        if isCurrent {
            return Palette.accent
        }
        return Palette.accent.opacity(0.45)
    }

    /// 内訳の横棒の幅。最大カテゴリを track 幅いっぱいにする。
    /// 記録があれば **最低 6pt** を保証し、小さいカテゴリが 0px で消えないようにする(⑥)。
    static func barWidth(_ minutes: Int, max maxMinutes: Int, track: Double) -> Double {
        if maxMinutes <= 0 || minutes <= 0 {
            return 0
        }
        let width = track * (Double(minutes) / Double(maxMinutes))
        let minVisible = 6.0
        if width < minVisible {
            return minVisible
        }
        if width > track {
            return track
        }
        return width
    }

    /// カテゴリごとの accent の濃さ(⑥)。宣言順に少しずつ薄くして見分けをつける。
    /// 手応え色(done/closer/next)とは意味が違うので流用せず、ブランドの accent の濃淡で表す。
    /// いちばん薄くても 0.45 までにして「無効」に見せない。並びは値ではなく種類で固定(順位の暗示を避ける)。
    static func categoryOpacity(_ category: StatsCategory) -> Double {
        switch category {
        case .whole: return 1.0
        case .individual: return 0.85
        case .game: return 0.72
        case .strength: return 0.6
        case .homeTraining: return 0.5
        case .other: return 0.45
        }
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
