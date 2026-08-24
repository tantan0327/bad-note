import SwiftUI

/// 課題の登録・編集画面(§3)。
///
/// 新規で必須なのは原文の 1 行だけ。他はすべて任意で、後から編集できる。
public struct IssueEditView: View {
    @State private var model: IssueEditModel
    @Environment(\.dismiss) private var dismiss

    /// - Parameter issueID: nil なら新規登録。
    public init(issueID: Int64? = nil) {
        _model = State(initialValue: IssueEditModel(issueID: issueID))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let errorText = model.errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                coachWordsSection
                doneFormSection
                disciplineSection
                masterySection
                impactSection
                costSection
                tagSection
            }
            .padding()
        }
        .navigationTitle(model.isNew ? Text("課題を追加", bundle: .module) : Text("課題を編集", bundle: .module))
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    model.save()
                    if model.isSaved {
                        dismiss()
                    }
                } label: {
                    Text("保存", bundle: .module)
                }
            }
        }
        .task {
            model.load()
        }
    }

    // MARK: - もとの言葉(原文)

    @ViewBuilder private var coachWordsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("もとの言葉", bundle: .module)
                .font(.headline)
            if model.isNew {
                TextField(text: $model.coachWords) {
                    Text("気づいたことを 1 行で", bundle: .module)
                }
                .textFieldStyle(.roundedBorder)
                Text("入れるのはこの 1 行だけで十分です", bundle: .module)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                // 原文は基本そのまま。ただし誤入力は直せるようにする(2026-08-24 決定)
                TextField(text: $model.coachWords) {
                    Text("気づいたことを 1 行で", bundle: .module)
                }
                .textFieldStyle(.roundedBorder)
                Text("原文はなるべくそのまま。直すのは誤字くらいに留めます", bundle: .module)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField(text: $model.coachName) {
                    Text("コーチ名(任意)", bundle: .module)
                }
                .textFieldStyle(.roundedBorder)
            }
        }
    }

    // MARK: - できている状態

    @ViewBuilder private var doneFormSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("できている状態(任意)", bundle: .module)
                .font(.headline)
            TextField(text: $model.doneForm) {
                Text("完了形で言い換える", bundle: .module)
            }
            .textFieldStyle(.roundedBorder)
            Text("後から整理するときに書けば十分です", bundle: .module)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 種目

    @ViewBuilder private var disciplineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("種目", bundle: .module)
                .font(.headline)
            HStack(spacing: 8) {
                disciplineButton(Text(Discipline.singles.displayName), value: .singles)
                disciplineButton(Text(Discipline.doubles.displayName), value: .doubles)
                disciplineButton(Text(Discipline.both.displayName), value: .both)
            }
            .font(.footnote)
        }
    }

    @ViewBuilder private func disciplineButton(_ label: Text, value: Discipline) -> some View {
        if model.discipline == value {
            Button { withAnimation(Motion.select) { model.discipline = value } } label: { label }.buttonStyle(.borderedProminent)
        } else {
            Button { withAnimation(Motion.select) { model.discipline = value } } label: { label }.buttonStyle(.bordered)
        }
    }

    // MARK: - 習熟度

    @ViewBuilder private var masterySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("習熟度", bundle: .module)
                .font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                masteryButton(Text(MasteryLevel.solo.displayName), value: .solo)
                masteryButton(Text(MasteryLevel.drill.displayName), value: .drill)
                masteryButton(Text(MasteryLevel.pattern.displayName), value: .pattern)
                masteryButton(Text(MasteryLevel.match.displayName), value: .match)
            }
            .font(.footnote)
        }
    }

    @ViewBuilder private func masteryButton(_ label: Text, value: MasteryLevel) -> some View {
        if model.masteryLevel == value {
            Button { withAnimation(Motion.select) { model.masteryLevel = value } } label: { label }.buttonStyle(.borderedProminent)
        } else {
            Button { withAnimation(Motion.select) { model.masteryLevel = value } } label: { label }.buttonStyle(.bordered)
        }
    }

    // MARK: - 影響度 / コスト

    @ViewBuilder private var impactSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("影響度(任意)", bundle: .module)
                .font(.headline)
            HStack(spacing: 8) {
                scaleButton(ScaleLabel.impact(1), isSelected: model.impact == 1) { model.toggleImpact(1) }
                scaleButton(ScaleLabel.impact(2), isSelected: model.impact == 2) { model.toggleImpact(2) }
                scaleButton(ScaleLabel.impact(3), isSelected: model.impact == 3) { model.toggleImpact(3) }
            }
            Text("試合の失点に直結するか", bundle: .module)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var costSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("習得コスト(任意)", bundle: .module)
                .font(.headline)
            HStack(spacing: 8) {
                scaleButton(ScaleLabel.cost(1), isSelected: model.cost == 1) { model.toggleCost(1) }
                scaleButton(ScaleLabel.cost(2), isSelected: model.cost == 2) { model.toggleCost(2) }
                scaleButton(ScaleLabel.cost(3), isSelected: model.cost == 3) { model.toggleCost(3) }
            }
            Text("直るまでの時間", bundle: .module)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private func scaleButton(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        if isSelected {
            Button(action: { withAnimation(Motion.select) { action() } }) { Text(verbatim: label) }.buttonStyle(.borderedProminent)
        } else {
            Button(action: { withAnimation(Motion.select) { action() } }) { Text(verbatim: label) }.buttonStyle(.bordered)
        }
    }

    // MARK: - タグ

    @ViewBuilder private var tagSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("タグ(任意)", bundle: .module)
                .font(.headline)
            ForEach(model.tags) { tag in
                HStack {
                    Text(tag.name)
                        .font(.footnote)
                    Spacer()
                    Button {
                        model.removeTag(tag)
                    } label: {
                        Text("外す", bundle: .module)
                            .font(.footnote)
                    }
                }
            }
            HStack(spacing: 8) {
                TextField(text: $model.tagDraft) {
                    Text("ショット種別など", bundle: .module)
                }
                .textFieldStyle(.roundedBorder)
                Button {
                    model.addTag()
                } label: {
                    Text("追加", bundle: .module)
                }
                .buttonStyle(.bordered)
            }
        }
    }
}
