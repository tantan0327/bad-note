import SwiftUI

/// インボックス整理画面(§3.1 の整理フェーズ)。
///
/// 未整理(`status = inbox`)の課題を 1 件ずつ処理する。出口は 3 つ:
/// 整理して `active` にする / 今は決めずに送る / もう不要なので消す。
public struct InboxTriageView: View {
    @State private var model = InboxTriageModel()
    @State private var isShowingDetails = false
    @Environment(\.dismiss) private var dismiss

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
                if let issue = model.current {
                    remainingLabel
                    coachWordsCard(issue)
                    // **読んで決めるだけで次へ行ける**(2026-10-12)。
                    // 言い換えも属性もすべて任意で、後から課題詳細で変えられる。
                    // 1 件ごとに 6 ブロック並べると、練習中に書いた 1 行が
                    // 後で記入必須のフォームになって現れることになる
                    DisclosureGroup(isExpanded: $isShowingDetails) {
                        VStack(alignment: .leading, spacing: 24) {
                            doneFormSection
                            disciplineSection
                            impactSection
                            costSection
                            tagSection
                        }
                        .padding(.top, 12)
                    } label: {
                        Text("くわしく決める(任意)", bundle: .module)
                            .font(.headline)
                    }
                    .accessibilityIdentifier("triage-details")
                    actionSection
                } else {
                    finishedSection
                }
            }
            .padding()
        }
        .navigationTitle(Text("課題を整理", bundle: .module))
        .confirmationDialog(Text("この課題を削除しますか?", bundle: .module),
                            isPresented: $model.isShowingDeleteConfirmation,
                            titleVisibility: .visible) {
            Button(role: .destructive) {
                model.delete()
            } label: {
                Text("削除する", bundle: .module)
            }
            Button(role: .cancel) {
            } label: {
                Text("やめる", bundle: .module)
            }
        }
        .onAppear {
            if model.queue.isEmpty {
                model.load()
            }
        }
    }

    @ViewBuilder private var remainingLabel: some View {
        Text(verbatim: "残り \(model.remainingCount) 件")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    /// 原文は編集しない。引用の見た目で出す(§7.3)。
    @ViewBuilder private func coachWordsCard(_ issue: Issue) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("もとの言葉", bundle: .module)
                .font(.headline)
            Card {
                Text(issue.coachWords)
            }
        }
    }

    @ViewBuilder private var doneFormSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("できている状態", bundle: .module)
                .font(.headline)
            TextField(text: $model.doneForm) {
                Text("完了形で言い換える", bundle: .module)
            }
            .textFieldStyle(.roundedBorder)
            .accessibilityIdentifier("triage-doneform")
            Text("思いつかなければ空のままでも進めます", bundle: .module)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var disciplineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("種目", bundle: .module)
                .font(.headline)
            HStack(spacing: 8) {
                selectionButton(Text(Discipline.singles.displayName), isSelected: model.discipline == .singles) {
                    model.discipline = .singles
                }
                .accessibilityIdentifier("triage-discipline-singles")
                selectionButton(Text(Discipline.doubles.displayName), isSelected: model.discipline == .doubles) {
                    model.discipline = .doubles
                }
                .accessibilityIdentifier("triage-discipline-doubles")
                selectionButton(Text(Discipline.both.displayName), isSelected: model.discipline == .both) {
                    model.discipline = .both
                }
                .accessibilityIdentifier("triage-discipline-both")
            }
            .font(.footnote)
        }
    }

    @ViewBuilder private var impactSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("影響度(任意)", bundle: .module)
                .font(.headline)
            HStack(spacing: 8) {
                selectionButton(Text(ScaleLabel.impact(1)), isSelected: model.impact == 1) { model.toggleImpact(1) }
                    .accessibilityIdentifier("triage-impact-1")
                selectionButton(Text(ScaleLabel.impact(2)), isSelected: model.impact == 2) { model.toggleImpact(2) }
                    .accessibilityIdentifier("triage-impact-2")
                selectionButton(Text(ScaleLabel.impact(3)), isSelected: model.impact == 3) { model.toggleImpact(3) }
                    .accessibilityIdentifier("triage-impact-3")
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
                selectionButton(Text(ScaleLabel.cost(1)), isSelected: model.cost == 1) { model.toggleCost(1) }
                    .accessibilityIdentifier("triage-cost-1")
                selectionButton(Text(ScaleLabel.cost(2)), isSelected: model.cost == 2) { model.toggleCost(2) }
                    .accessibilityIdentifier("triage-cost-2")
                selectionButton(Text(ScaleLabel.cost(3)), isSelected: model.cost == 3) { model.toggleCost(3) }
                    .accessibilityIdentifier("triage-cost-3")
            }
            Text("直るまでの時間", bundle: .module)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

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
                .accessibilityIdentifier("triage-tag-field")
                Button {
                    model.addTag()
                } label: {
                    Text("追加", bundle: .module)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("triage-tag-add")
            }
        }
    }

    // MARK: - 出口

    @ViewBuilder private var actionSection: some View {
        VStack(spacing: 12) {
            Button {
                model.organize()
            } label: {
                Text("整理して次へ", bundle: .module)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("triage-organize")

            HStack(spacing: 12) {
                Button {
                    model.skip()
                } label: {
                    Text("今はスキップ", bundle: .module)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("triage-skip")

                Button(role: .destructive) {
                    model.isShowingDeleteConfirmation = true
                } label: {
                    Text("もう不要", bundle: .module)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("triage-delete")
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder private var finishedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if model.queue.isEmpty {
                Text("整理する課題はありません", bundle: .module)
                    .font(.headline)
            } else {
                Text("整理が終わりました", bundle: .module)
                    .font(.headline)
                Text(verbatim: "\(model.organizedCount) 件を整理しました")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Button {
                dismiss()
            } label: {
                Text("閉じる", bundle: .module)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder private func selectionButton(_ label: Text, isSelected: Bool, action: @escaping () -> Void) -> some View {
        if isSelected {
            Button(action: action) { label }.buttonStyle(.borderedProminent)
        } else {
            Button(action: action) { label }.buttonStyle(.bordered)
        }
    }
}
