import SwiftUI

/// 大会詳細(§7.5)。
///
/// 基本情報 / この大会までに / 調整期の帯 / 大会後の振り返り。
/// 当日を過ぎると振り返りのフォームに切り替わる。
public struct CompetitionDetailView: View {
    @State private var model: CompetitionDetailModel
    @State private var isShowingDeleteConfirmation = false
    @Environment(\.dismiss) private var dismiss

    public init(competitionID: Int64) {
        _model = State(initialValue: CompetitionDetailModel(competitionID: competitionID))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let errorText = model.errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                if let savedMessage = model.savedMessage {
                    Text(savedMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let competition = model.competition {
                    basicSection(competition)
                    if model.isAdjustmentPeriod {
                        adjustmentBanner
                    }
                    if model.isFinished {
                        reviewSection
                    } else {
                        issueSections
                    }
                }
            }
            .padding()
        }
        .navigationTitle(Text("大会", bundle: .module))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                // 削除はメニューの奥に置く。気軽に消せる場所に置かない(§7.5)
                Menu {
                    NavigationLink {
                        CompetitionEditView(competitionID: model.competition?.id ?? 0)
                    } label: {
                        Text("編集する", bundle: .module)
                    }
                    Button(role: .destructive) {
                        isShowingDeleteConfirmation = true
                    } label: {
                        Text("この大会を削除", bundle: .module)
                    }
                } label: {
                    Text(verbatim: "⋯")
                }
            }
        }
        .confirmationDialog(Text("この大会を削除しますか?", bundle: .module),
                            isPresented: $isShowingDeleteConfirmation,
                            titleVisibility: .visible) {
            Button(role: .destructive) {
                model.delete()
                dismiss()
            } label: {
                Text("削除する", bundle: .module)
            }
            Button(role: .cancel) {
            } label: {
                Text("やめる", bundle: .module)
            }
        }
        .onAppear {
            model.load()
        }
    }

    // MARK: - 1. 基本情報

    @ViewBuilder private func basicSection(_ competition: Competition) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(competition.name)
                .font(.title2)
            Text(competition.eventDate.formatted(date: .abbreviated, time: .omitted))
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let venue = competition.venue, !venue.isEmpty {
                Text(venue)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if !model.isFinished {
                Text(remainingText())
                    .font(.system(size: 28, weight: .semibold))
            } else {
                Text("終了しました", bundle: .module)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// 「あと 42日 / 12回」。回数が推定できないときは日数だけ(§5.2)。
    private func remainingText() -> String {
        let days = model.remainingDays == 0 ? "今日" : "あと \(model.remainingDays)日"
        if let practices = model.remainingPractices {
            return "\(days) / \(practices)回"
        }
        return days
    }

    // MARK: - 3. 調整期の帯

    @ViewBuilder private var adjustmentBanner: some View {
        Text("調整期です。新しい課題は増やさず、今の 3 つに集中します", bundle: .module)
            .font(.footnote)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.15))
            .cornerRadius(8)
    }

    // MARK: - 2. この大会までに

    @ViewBuilder private var issueSections: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("この大会までに", bundle: .module)
                .font(.headline)
            if model.sections.isEmpty {
                Text("出場する種目が登録されていません", bundle: .module)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(model.sections) { section in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(section.discipline.displayName)
                            .font(.subheadline)
                        if section.isTarget {
                            Text("★ 目標大会", bundle: .module)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if section.issues.isEmpty {
                        Text("紐付いた課題はありません", bundle: .module)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(section.issues) { issue in
                        NavigationLink {
                            IssueDetailView(issueID: issue.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(issue.displayTitle)
                                    .font(.body)
                                if section.isTight(issue) {
                                    // §7.5 控えめに提示する。警告にしない
                                    Text("この大会では厳しいかもしれません", bundle: .module)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
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
        }
    }

    // MARK: - 4. 大会後の振り返り(種目ごとに 1 セット)

    @ViewBuilder private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("振り返り", bundle: .module)
                .font(.headline)
            ForEach(0..<model.reviews.count, id: \.self) { index in
                reviewForm(index)
            }
        }
    }

    @ViewBuilder private func reviewForm(_ index: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.reviews[index].discipline.displayName)
                .font(.subheadline)

            field(Text("結果", bundle: .module), text: $model.reviews[index].result)
            field(Text("うまくいったことは何か", bundle: .module), text: $model.reviews[index].wentWell)
            field(Text("理想の姿に近づくために次にやることは何か", bundle: .module),
                  text: $model.reviews[index].nextAction)
            field(Text("そのために必要なもの(人・道具・情報)は何か", bundle: .module),
                  text: $model.reviews[index].neededResources)

            HStack(spacing: 8) {
                Button {
                    model.saveReview(model.reviews[index])
                } label: {
                    Text("保存", bundle: .module)
                }
                .buttonStyle(.borderedProminent)
                // §7.5 3 つ目の回答からそのまま課題を登録できる導線
                Button {
                    model.createIssueFromNextAction(model.reviews[index])
                } label: {
                    Text("次にやることを課題にする", bundle: .module)
                }
                .buttonStyle(.bordered)
            }
            .font(.footnote)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }

    @ViewBuilder private func field(_ label: Text, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            label
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(text: text) {
                Text("", bundle: .module)
            }
            .textFieldStyle(.roundedBorder)
        }
    }
}
