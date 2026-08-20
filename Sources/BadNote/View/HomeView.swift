import SwiftUI

/// ホーム画面(§7.1)。
///
/// 上から めざす姿 / カウントダウン / 今週の重点 / 練習を記録するボタン。
///
/// §5.3 やらないこと —— ストリーク、課題の総数、未整理件数のバッジは**出さない**。
/// 数字は積み上げ側(今月の練習時間・レベルアップ回数)だけ。
public struct HomeView: View {
    @State private var model = HomeModel()
    @State private var isShowingPracticeLog = false

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
                visionSection
                countdownSection
                focusSection
                recordButton
            }
            .padding()
        }
        .navigationTitle(Text("ホーム", bundle: .module))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    IssueListView()
                } label: {
                    Text("課題", bundle: .module)
                }
            }
        }
        .sheet(isPresented: $isShowingPracticeLog) {
            PracticeLogView()
        }
        .onAppear {
            model.load()
        }
    }

    // MARK: - 1. めざす姿(常設。カウントダウンより上)

    @ViewBuilder private var visionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("めざす姿", bundle: .module)
                .font(.headline)
            if model.vision.isEmpty {
                // 初回は促さない(§7.1)。空でも場所だけ確保しておく
                Text("まだ書かれていません", bundle: .module)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text(model.vision.body)
                    .font(.title3)
            }
        }
    }

    // MARK: - 2. カウントダウン(種目ごと。近いほうを上に大きく)

    @ViewBuilder private var countdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.countdowns.isEmpty {
                if !model.hasTargetCompetition {
                    // 大会なしでもアプリは成立させる(§7.1)
                    Text("大会を登録する", bundle: .module)
                        .font(.headline)
                    Text("目標の大会を決めると、残り日数と練習回数が出ます", bundle: .module)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(model.countdowns) { countdown in
                countdownCard(countdown)
            }
            if model.isAdjustmentPeriod {
                // §4.4 調整期。直前に忘れていた課題を掘り返さない期間
                Text("調整期です。新しい課題は増やさず、今の 3 つに集中します", bundle: .module)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private func countdownCard(_ countdown: HomeModel.Countdown) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(disciplineName(countdown.discipline))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(countdown.competition.name)
                    .font(.footnote)
            }
            // §5.1 8 週間を境に、大きく出す数字を入れ替える(種目ごとに独立)
            if countdown.emphasis == HomeEmphasis.countdown {
                Text(remainingText(countdown))
                    .font(.system(size: 34, weight: .semibold))
                Text(buildUpText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(buildUpText)
                    .font(.system(size: 34, weight: .semibold))
                Text(remainingText(countdown))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }

    /// 「あと 42日 / 12回」。回数が推定できないときは日数だけ(§5.2)。
    private func remainingText(_ countdown: HomeModel.Countdown) -> String {
        let days = countdown.remainingDays == 0 ? "今日" : "あと \(countdown.remainingDays)日"
        if let practices = countdown.remainingPractices {
            return "\(days) / \(practices)回"
        }
        return days
    }

    /// 「今月 14 時間 / レベルアップ 2」
    private var buildUpText: String {
        let hours = model.monthMinutes / 60
        let time = model.monthMinutes >= 60 ? "\(hours) 時間" : "\(model.monthMinutes) 分"
        return "今月 \(time) / レベルアップ \(model.monthLevelUps)"
    }

    // MARK: - 3. 今週の重点(スクロールなしで 3 つ見える)

    @ViewBuilder private var focusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("今週の重点", bundle: .module)
                .font(.headline)
            if model.focusCards.isEmpty {
                Text("重点はまだ決まっていません", bundle: .module)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(model.focusCards) { card in
                NavigationLink {
                    IssueEditView(issueID: card.issue.id)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(card.issue.displayTitle)
                            .font(.body)
                        HStack(spacing: 8) {
                            Text(masteryName(card.issue.masteryLevel))
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.2))
                                .cornerRadius(4)
                            if let result = card.latestResult {
                                Text(resultName(result))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - 5. 練習を記録するボタン(末尾に大きく)

    @ViewBuilder private var recordButton: some View {
        Button {
            isShowingPracticeLog = true
        } label: {
            Text("練習を記録する", bundle: .module)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .padding(.top, 8)
    }

    // MARK: - 表示名

    private func disciplineName(_ discipline: Discipline) -> String {
        switch discipline {
        case .singles: return "シングルス"
        case .doubles: return "ダブルス"
        case .both: return "両方"
        }
    }

    private func masteryName(_ level: MasteryLevel) -> String {
        switch level {
        case .solo: return "素振り"
        case .drill: return "ノック"
        case .pattern: return "パターン練習"
        case .match: return "試合"
        }
    }

    private func resultName(_ result: FocusResult) -> String {
        switch result {
        case .done: return "できた"
        case .closer: return "近づいた"
        case .next: return "次にやる"
        }
    }
}
