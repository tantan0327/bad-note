import SwiftUI

/// 課題詳細(§7.3)。
///
/// 上から できている状態 / 習熟度 / もとの言葉 / 記録 / 進み方 / 属性 / アクション。
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
                    attributesSection(issue)
                    actionSection(issue)
                }
            }
            .padding()
        }
        .navigationTitle(Text("課題", bundle: .module))
        .onAppear {
            model.load()
        }
    }

    // MARK: - 1. できている状態(最上部に大きく)

    @ViewBuilder private func doneFormSection(_ issue: Issue) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(issue.displayTitle)
                .font(.title2)
            if issue.isFrequentlyResurfacing {
                // §7.3 よく戻ってくる課題。弱点の本質を示す情報として出す
                Text("よく戻ってくる課題", bundle: .module)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Palette.surfaceRaised)
                    .cornerRadius(4)
            }
        }
    }

    // MARK: - 2. 習熟度(4 段階のステップ表示)

    @ViewBuilder private func masterySection(_ issue: Issue) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("習熟度", bundle: .module)
                .font(.headline)
            ForEach(MasteryLevel.allCases, id: \.rawValue) { level in
                HStack(spacing: 8) {
                    Text(verbatim: level.rawValue <= issue.masteryLevel.rawValue ? "●" : "○")
                        .foregroundStyle(level == issue.masteryLevel ? Palette.accent : Color.secondary)
                    Text(level.displayName)
                        .font(level == issue.masteryLevel ? .body : .footnote)
                        .foregroundStyle(level == issue.masteryLevel ? Color.primary : Color.secondary)
                }
            }
            if let next = model.nextLevel {
                Button {
                    model.raiseLevel()
                } label: {
                    Text(verbatim: "「\(next.displayName)」に上げる")
                }
                .buttonStyle(.borderedProminent)
                .font(.footnote)
            }
        }
    }

    // MARK: - 3. もとの言葉(引用の見た目)

    @ViewBuilder private func coachWordsSection(_ issue: Issue) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("もとの言葉", bundle: .module)
                .font(.headline)
            Text(issue.coachWords)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.surface)
                .cornerRadius(8)
            HStack(spacing: 8) {
                if let coachName = issue.coachName, !coachName.isEmpty {
                    Text(coachName)
                }
                Text(issue.createdAt.formatted(date: .abbreviated, time: .omitted))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - 4. 記録

    @ViewBuilder private func recordSection(_ issue: Issue) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("記録", bundle: .module)
                .font(.headline)
            HStack(spacing: 24) {
                record(Text("累計時間", bundle: .module), value: timeText(model.totalMinutes))
                record(Text("重点にした", bundle: .module), value: "\(model.focusCount) 回")
                record(Text("再浮上", bundle: .module), value: "\(issue.resurfaceCount) 回")
            }
        }
    }

    @ViewBuilder private func record(_ label: Text, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            label
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(verbatim: value)
                .font(.title3)
        }
    }

    private func timeText(_ minutes: Int) -> String {
        return minutes >= 60 ? "\(minutes / 60) 時間" : "\(minutes) 分"
    }

    // MARK: - 5. 進み方(色分けした点。文字にしない)

    @ViewBuilder private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("進み方", bundle: .module)
                .font(.headline)
            if model.progress.isEmpty {
                Text("まだ記録がありません", bundle: .module)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(0..<model.progress.count, id: \.self) { index in
                            progressMark(model.progress[index])
                        }
                    }
                }
            }
        }
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

    // MARK: - 6. 属性(折りたたみ)

    @ViewBuilder private func attributesSection(_ issue: Issue) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                isShowingAttributes = !isShowingAttributes
            } label: {
                Text(isShowingAttributes ? "属性を閉じる" : "属性を見る", bundle: .module)
                    .font(.headline)
            }
            if isShowingAttributes {
                VStack(alignment: .leading, spacing: 6) {
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
                }
                .font(.footnote)
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

    // MARK: - 7. アクション

    @ViewBuilder private func actionSection(_ issue: Issue) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.isArchived {
                // アーカイブ済みのときだけ出す(§7.3)
                Button {
                    model.resurface()
                } label: {
                    Text("再浮上させる", bundle: .module)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                Text("レベルは 1 つ下から再開します", bundle: .module)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Button {
                    model.overcome()
                } label: {
                    Text("克服した(定着確認へ)", bundle: .module)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.bordered)
                if let rejection = model.overcomeRejection {
                    // §7.3 Lv.3 以下で押したら理由を出す
                    Text(rejection)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if issue.masteryLevel != MasteryLevel.solo {
                    // 日常操作ではないので控えめに置く(§3.2)
                    Button {
                        model.lowerLevel()
                    } label: {
                        Text("レベルを 1 つ下げる", bundle: .module)
                            .font(.footnote)
                    }
                }
            }
        }
        .padding(.top, 8)
    }
}
