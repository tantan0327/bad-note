import SwiftUI

/// 課題詳細(§7.3)。
///
/// 上から できている状態 / 習熟度 / もとの言葉 / 記録 / 進み方 / アクション / 属性。
/// 属性は日常で使わないのでいちばん下(「克服した」を折り返しの外に沈めない。2.2)。
public struct IssueDetailView: View {
    @State private var model: IssueDetailModel
    @State private var isShowingAttributes = false

    public init(issueID: Int64) {
        _model = State(initialValue: IssueDetailModel(issueID: issueID))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let errorText = model.errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                if let issue = model.issue {
                    doneFormSection(issue)
                    masterySection(issue)
                    coachWordsSection(issue)
                    recordSection(issue)
                    progressSection
                    actionSection(issue)
                    attributesSection(issue)
                }
            }
            .padding()
        }
        // タイトルは「課題」ではなく課題名そのもの。画面でいちばん大きい文字は
        // 中身のある言葉にする(tasks.md 1.2)
        .navigationTitle(Text(model.issue?.displayTitle ?? ""))
        #if os(iOS) || os(Android)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            model.load()
        }
    }

    // MARK: - 1. できている状態(最上部に大きく)

    @ViewBuilder private func doneFormSection(_ issue: Issue) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(issue.displayTitle)
                .font(.title2)
            HStack(spacing: 8) {
                if issue.isFrequentlyResurfacing {
                    // §7.3 よく戻ってくる課題。弱点の本質を示す情報として出す
                    Badge(label: Text("よく戻ってくる課題", bundle: .module))
                }
                // 影響度 × コストの目印(§3.4)。「属性を見る」の奥に隠さない
                if let hint = PriorityHint.forIssue(impact: issue.impact, cost: issue.cost) {
                    Badge(label: Text(hint.displayName), tint: hint.tint)
                }
            }
            metaLine(issue)
        }
    }

    // MARK: - 2. 習熟度(横 4 分割のバー)

    @ViewBuilder private func masterySection(_ issue: Issue) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("習熟度", bundle: .module)
                .font(.headline)
            // ●○ の文字をやめ、進み具合の部品にする(2.2)。埋まった数 = 現在のレベル
            HStack(spacing: 4) {
                ForEach(MasteryLevel.allCases, id: \.rawValue) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(level.rawValue <= issue.masteryLevel.rawValue ? Palette.accent : Palette.surfaceRaised)
                        .frame(height: 8)
                }
            }
            .accessibilityLabel(Text("習熟度", bundle: .module))
            .accessibilityValue(Text(verbatim: "\(issue.masteryLevel.rawValue)/4 \(issue.masteryLevel.displayName)"))
            Text(issue.masteryLevel.displayName)
                .font(.body)
            if let next = model.nextLevel {
                Button {
                    // バーの伸びは速く動かす(5.1)
                    withAnimation(Motion.select) {
                        model.raiseLevel()
                    }
                } label: {
                    Text(verbatim: "「\(next.displayName)」に上げる")
                }
                .buttonStyle(.borderedProminent)
                .font(.footnote)
                .accessibilityIdentifier("issue-detail-raise")
            }
        }
    }

    // MARK: - 3. もとの言葉(引用の見た目)

    /// **言い換えを持っている課題にだけ出す**(2026-08-26)。
    ///
    /// 持っていない課題では `displayTitle` が原文そのものなので、引用すると
    /// 画面の上の見出しと同じ文が 2 度出る(ナビゲーションタイトルと合わせて 3 度)。
    /// 追加画面を 1 欄にしてから、言い換えを持たない課題のほうが多い。
    /// コーチ名と日付は引用が無くても要るので、見出しの直下(`doneFormSection`)に移した。
    @ViewBuilder private func coachWordsSection(_ issue: Issue) -> some View {
        if issue.hasDoneForm {
            VStack(alignment: .leading, spacing: 8) {
                Text("もとの言葉", bundle: .module)
                    .font(.headline)
                Card {
                    Text(issue.coachWords)
                }
            }
        }
    }

    /// コーチ名と書いた日。**課題そのものの情報**なので、引用の有無に関わらず出す。
    @ViewBuilder private func metaLine(_ issue: Issue) -> some View {
        HStack(spacing: 8) {
            if let coachName = issue.coachName, !coachName.isEmpty {
                Text(coachName)
            }
            Text(DateText.day(issue.createdAt))
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    // MARK: - 4. 記録

    @ViewBuilder private func recordSection(_ issue: Issue) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("記録", bundle: .module)
                .font(.headline)
            // 数字が主役の場所なので面に載せ、積み上げ画面と同じ形にする(2.2)
            Card {
                HStack(spacing: 12) {
                    StatItem(value: timeValue(model.totalMinutes),
                             unit: timeUnit(model.totalMinutes),
                             label: Text("累計時間", bundle: .module))
                    StatItem(value: model.focusCount,
                             unit: Text("回", bundle: .module),
                             label: Text("重点にした", bundle: .module))
                    StatItem(value: issue.resurfaceCount,
                             unit: Text("回", bundle: .module),
                             label: Text("再浮上", bundle: .module))
                }
            }
        }
    }

    /// 60 分以上は時間で、未満は分で出す(値と単位に分ける。形は `StatItem`)。
    private func timeValue(_ minutes: Int) -> Int {
        return minutes >= 60 ? minutes / 60 : minutes
    }

    private func timeUnit(_ minutes: Int) -> Text {
        return minutes >= 60 ? Text("時間", bundle: .module) : Text("分", bundle: .module)
    }

    // MARK: - 5. 進み方(色分けした点。文字にしない)

    @ViewBuilder private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("進み方", bundle: .module)
                .font(.headline)
            if model.progress.isEmpty {
                // 記録が増えるのを待つだけの場所。次の 1 手は置かない(2.4)
                EmptyStateView(message: Text("まだ記録がありません", bundle: .module)) {
                    EmptyView()
                }
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(0..<model.progress.count, id: \.self) { index in
                            progressMark(model.progress[index])
                        }
                    }
                }
                // 点の列は VoiceOver に伝わらないので、まとめて読み上げる(6.1)
                .accessibilityLabel(Text("進み方", bundle: .module))
                .accessibilityValue(Text(verbatim: progressSummary()))
            }
        }
    }

    /// 「できた2回、近づいた1回 …」。VoiceOver 用の要約。0 回の区分は読まない。
    private func progressSummary() -> String {
        var done = 0
        var closer = 0
        var next = 0
        var blank = 0
        for result in model.progress {
            switch result {
            case .done: done += 1
            case .closer: closer += 1
            case .next: next += 1
            case nil: blank += 1
            }
        }
        var parts: [String] = []
        if done > 0 { parts.append("できた\(done)回") }
        if closer > 0 { parts.append("近づいた\(closer)回") }
        if next > 0 { parts.append("次にやる\(next)回") }
        if blank > 0 { parts.append("記録なし\(blank)回") }
        return parts.joined(separator: "、")
    }

    /// 手応えは色と形の両方で区別する(色だけに頼らない。tasks.md 1.1 / 6.1)。
    /// できた = 塗り丸 / 近づいた = 輪 / 次にやる = 四角 / 記録なし = 小さな点。
    @ViewBuilder private func progressMark(_ result: FocusResult?) -> some View {
        if let result = result {
            switch result {
            case .done:
                Circle()
                    .fill(Palette.done)
                    .frame(width: 12, height: 12)
            case .closer:
                Circle()
                    .stroke(Palette.closer, lineWidth: 3)
                    .frame(width: 9, height: 9)
                    .frame(width: 12, height: 12)
            case .next:
                RoundedRectangle(cornerRadius: 2)
                    .fill(Palette.next)
                    .frame(width: 11, height: 11)
                    .frame(width: 12, height: 12)
            }
        } else {
            Circle()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 5, height: 5)
                .frame(width: 12, height: 12)
        }
    }

    // MARK: - 7. 属性(折りたたみ。日常で使わないのでいちばん下)

    @ViewBuilder private func attributesSection(_ issue: Issue) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 導線は他の画面と同じ形(bordered + footnote)。裸の青リンクにしない(2.2)
            Button {
                isShowingAttributes = !isShowingAttributes
            } label: {
                Text(isShowingAttributes ? "属性を閉じる" : "属性を見る", bundle: .module)
                    .font(.footnote)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("issue-detail-attributes")
            if isShowingAttributes {
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        attribute(Text("種目", bundle: .module), value: issue.discipline.displayName)
                        attribute(Text("優先度", bundle: .module), value: tierName(issue.tier))
                        if let impact = issue.impact {
                            attribute(Text("影響度", bundle: .module), value: ScaleLabel.impact(impact))
                        }
                        if let cost = issue.cost {
                            attribute(Text("習得コスト", bundle: .module), value: ScaleLabel.cost(cost))
                        }
                        if !model.tags.isEmpty {
                            attribute(Text("タグ", bundle: .module), value: tagText())
                        }
                        NavigationLink {
                            IssueEditView(issueID: issue.id)
                        } label: {
                            Text("編集する", bundle: .module)
                                .font(.footnote)
                        }
                        .accessibilityIdentifier("issue-detail-edit")
                    }
                    .font(.footnote)
                }
            }
        }
    }

    @ViewBuilder private func attribute(_ label: Text, value: String) -> some View {
        HStack {
            label.foregroundStyle(.secondary)
            Spacer()
            Text(verbatim: value)
        }
    }

    private func tierName(_ tier: Tier) -> String {
        switch tier {
        case .focus: return "今週の重点"
        case .next: return "次にやる"
        case .someday: return "いつか"
        }
    }

    private func tagText() -> String {
        var names: [String] = []
        for tag in model.tags {
            names.append(tag.name)
        }
        return names.joined(separator: " / ")
    }

    // MARK: - 6. アクション(属性より上。折り返しの外に沈めない)

    @ViewBuilder private func actionSection(_ issue: Issue) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.isArchived {
                // アーカイブ済みのときだけ出す(§7.3)
                Button {
                    withAnimation(Motion.move) {
                        model.resurface()
                    }
                } label: {
                    Text("再浮上させる", bundle: .module)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("issue-detail-resurface")
                Text("レベルは 1 つ下から再開します", bundle: .module)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Button {
                    withAnimation(Motion.move) {
                        model.overcome()
                    }
                } label: {
                    Text("克服した(定着確認へ)", bundle: .module)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("issue-detail-overcome")
                if let rejection = model.overcomeRejection {
                    // §7.3 Lv.3 以下で押したら理由を出す
                    Text(rejection)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if issue.masteryLevel != MasteryLevel.solo {
                    // 日常操作ではないので控えめに置く(§3.2)
                    Button {
                        withAnimation(Motion.select) {
                            model.lowerLevel()
                        }
                    } label: {
                        Text("レベルを 1 つ下げる", bundle: .module)
                            .font(.footnote)
                    }
                    .accessibilityIdentifier("issue-detail-lower")
                }
            }
        }
        .padding(.top, 8)
    }
}
