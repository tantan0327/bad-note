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
                staleSection
                statsLink
                recordButton
            }
            .padding()
        }
        // 大タイトル「ホーム」は出さない。いちばん上の場所はめざす姿に譲る(tasks.md 1.2)
        .navigationTitle(Text("ホーム", bundle: .module))
        #if os(iOS) || os(Android)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image("settings", bundle: .module)
                }
                .accessibilityLabel(Text("設定", bundle: .module, comment: "accessibility label for the settings button"))
            }
        }
        .sheet(isPresented: $isShowingPracticeLog) {
            PracticeLogView()
        }
        .confirmationDialog(Text("どれと入れ替えますか?", bundle: .module),
                            isPresented: $model.isShowingSwap,
                            titleVisibility: .visible) {
            ForEach(model.swapCandidates) { candidate in
                Button {
                    model.confirmSwap(with: candidate)
                } label: {
                    Text(candidate.displayTitle)
                }
            }
            Button(role: .cancel) {
                model.cancelSwap()
            } label: {
                Text("やめる", bundle: .module)
            }
        }
        .onAppear {
            model.load()
        }
    }

    // MARK: - 1. めざす姿(常設。カウントダウンより上)

    @ViewBuilder private var visionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // §7.1 の主役。見出しは小さく添えるだけにして、本文を画面最大の文字にする(tasks.md 1.2)
            Text("めざす姿", bundle: .module)
                .font(.caption)
                .foregroundStyle(.secondary)
            NavigationLink {
                VisionEditView()
            } label: {
                if model.vision.isEmpty {
                    // 初回は促さない(§7.1)。空でも場所だけ確保する。
                    // タップで編集に入れるので、ここにボタンは足さない(2.4)
                    EmptyStateView(message: Text("まだ書かれていません", bundle: .module)) {
                        EmptyView()
                    }
                } else {
                    Text(model.vision.body)
                        .font(.title2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        // 本文なのでリンク色にしない
                        .foregroundStyle(.primary)
                }
            }
            if model.isPromptingVision {
                visionPrompt
            }
        }
    }

    /// §7.1 数回使った後に 1 度だけ促す。
    @ViewBuilder private var visionPrompt: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("めざす姿を書いてみませんか", bundle: .module)
                    .font(.body)
                Text("何をめざしているかが決まると、大会と今週の重点に意味が出ます", bundle: .module)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    NavigationLink {
                        VisionEditView()
                    } label: {
                        Text("書く", bundle: .module)
                    }
                    .buttonStyle(.borderedProminent)
                    Button {
                        model.dismissVisionPrompt()
                    } label: {
                        Text("あとで", bundle: .module)
                    }
                    .buttonStyle(.bordered)
                }
                .font(.footnote)
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
        Card {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(countdown.discipline.displayName)
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
        }
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
            HStack {
                Text("今週の重点", bundle: .module)
                    .font(.headline)
                Spacer()
                // 一覧側と同じ「1/3」。あと何枠選べるかが分かる(2.1)
                Text(verbatim: "\(model.focusCards.count)/\(FocusBoard.focusCapacity)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if model.focusCards.isEmpty {
                if model.isJustStarting {
                    // 4.1 ほんとうの初回。課題ゼロで「重点を選ぶ」を出すと
                    // 候補の無い組み替え画面に行き着くので、最初の 1 歩に差し替える
                    EmptyStateView(icon: "checklist",
                                   message: Text("まずは気になっていることを、課題として 1 行書くところから。練習のあとなら下の「練習を記録する」からでも始められます", bundle: .module)) {
                        NavigationLink {
                            IssueEditView()
                        } label: {
                            Text("課題を書く", bundle: .module)
                                .font(.footnote)
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("home-first-step-action")
                    }
                } else {
                    // 次の 1 手 —— 組み替えモードで重点を選ぶ(2.4)
                    EmptyStateView(icon: "checklist",
                                   message: Text("重点はまだ決まっていません", bundle: .module)) {
                        NavigationLink {
                            FocusReshuffleView()
                        } label: {
                            Text("重点を選ぶ", bundle: .module)
                                .font(.footnote)
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("home-focus-empty-action")
                    }
                }
            }
            ForEach(model.focusCards) { card in
                Card {
                    NavigationLink {
                        IssueDetailView(issueID: card.issue.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(card.issue.displayTitle)
                                .font(.body)
                            HStack(spacing: 8) {
                                // 一覧の行と同じ形(2.3)。文字チップより進み具合が見える
                                MasteryIndicator(level: card.issue.masteryLevel)
                                if let result = card.latestResult {
                                    Text(result.displayName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(.primary)
                    }
                }
            }
            // §7.1 カード 3 枚。空き枠が見えること自体が「あと N 個選べる」の合図(2.1)。
            // 0 件のときは上の EmptyStateView に譲る
            if !model.focusCards.isEmpty && model.focusCards.count < FocusBoard.focusCapacity {
                ForEach(0..<(FocusBoard.focusCapacity - model.focusCards.count), id: \.self) { index in
                    emptyFocusSlot(index)
                }
            }
        }
    }

    /// 空き枠。押すと組み替えモードへ。宿題に見せない(§5.3)—— 件数の催促はしない。
    @ViewBuilder private func emptyFocusSlot(_ index: Int) -> some View {
        Card {
            NavigationLink {
                FocusReshuffleView()
            } label: {
                HStack {
                    Text("空き枠", bundle: .module)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("選ぶ", bundle: .module)
                        .font(.footnote)
                }
            }
        }
        .accessibilityIdentifier("home-focus-empty-slot-\(index)")
    }

    // MARK: - 4. しばらく触れていない課題(該当時のみ)

    @ViewBuilder private var staleSection: some View {
        if !model.staleItems.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("しばらく触れていない課題", bundle: .module)
                    .font(.headline)
                ForEach(model.staleItems) { item in
                    Card {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.issue.displayTitle)
                                .font(.body)
                            // 理由を添える(§4.3)
                            Text(item.reason.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            // 3 択をその場で完結させる。別画面に飛ばさない
                            HStack(spacing: 8) {
                                Button {
                                    model.focusOnStaleIssue(item)
                                } label: {
                                    Text("今週の重点にする", bundle: .module)
                                }
                                .buttonStyle(.borderedProminent)
                                Button {
                                    model.postponeStaleIssue(item)
                                } label: {
                                    Text("まだいい", bundle: .module)
                                }
                                .buttonStyle(.bordered)
                                Button {
                                    model.archiveStaleIssue(item)
                                } label: {
                                    Text("もう不要", bundle: .module)
                                }
                                .buttonStyle(.bordered)
                            }
                            .font(.caption)
                        }
                    }
                }
            }
        }
    }

    // MARK: - 5. 積み上げ(通算はホームにも大きく出す —— 2.1 で決定)

    @ViewBuilder private var statsLink: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("積み上げ", bundle: .module)
                .font(.headline)
            Card {
                NavigationLink {
                    StatsView()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        if model.lifetimeMinutes > 0 {
                            // 減らない数字(§5.3)。分まで出すのは積み上げ画面の主役と同じ
                            Text(StatsView.heroTimeText(model.lifetimeMinutes))
                                .font(.system(size: 34, weight: .semibold))
                                .foregroundStyle(.primary)
                            Text("通算の練習時間。月ごとと種類の内訳を見る", bundle: .module)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            // まだ 0 のときに大きな「0分」を出さない(空の状態は静かに)
                            Text("記録すると、ここに通算の時間が積み上がっていきます", bundle: .module)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityIdentifier("home-stats-link")
            }
        }
    }

    // MARK: - 6. 練習を記録するボタン(末尾に大きく)

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

}
