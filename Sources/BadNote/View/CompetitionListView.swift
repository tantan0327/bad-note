import SwiftUI

/// 大会一覧(§7.5)。
///
/// これからの大会を日付順、下に終了した大会。目標大会には印を付ける。
/// 詳細(この大会までに / 振り返り)は未実装。
public struct CompetitionListView: View {
    @State private var model = CompetitionListModel()

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
                if model.upcoming.isEmpty && model.finished.isEmpty {
                    // 大会なしでもアプリは成立させる(§7.1)
                    Text("大会はまだ登録されていません", bundle: .module)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                section(title: Text("これからの大会", bundle: .module), rows: model.upcoming)
                section(title: Text("終了した大会", bundle: .module), rows: model.finished)
            }
            .padding()
        }
        .navigationTitle(Text("大会", bundle: .module))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    CompetitionEditView()
                } label: {
                    Text("追加", bundle: .module)
                }
            }
        }
        .onAppear {
            model.load()
        }
    }

    @ViewBuilder private func section(title: Text, rows: [CompetitionListModel.Row]) -> some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                title.font(.headline)
                ForEach(rows) { row in
                    NavigationLink {
                        CompetitionDetailView(competitionID: row.competition.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.competition.name)
                                .font(.body)
                            Text(dateText(row.competition.eventDate))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if !row.targetDisciplines.isEmpty {
                                // 目標大会の印(§7.5)
                                Text(targetText(row.targetDisciplines))
                                    .font(.caption)
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

    private func dateText(_ date: Date) -> String {
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func targetText(_ disciplines: [Discipline]) -> String {
        var names: [String] = []
        for discipline in disciplines {
            names.append(discipline.displayName)
        }
        return "★ 目標大会(" + names.joined(separator: " / ") + ")"
    }
}

/// 大会の登録・編集(§7.5)。
public struct CompetitionEditView: View {
    @State private var model: CompetitionEditModel
    @Environment(\.dismiss) private var dismiss

    public init(competitionID: Int64? = nil) {
        _model = State(initialValue: CompetitionEditModel(competitionID: competitionID))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let errorText = model.errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("大会名", bundle: .module)
                        .font(.headline)
                    TextField(text: $model.name) {
                        Text("県大会 など", bundle: .module)
                    }
                    .textFieldStyle(.roundedBorder)
                }

                DatePicker(selection: $model.eventDate, displayedComponents: .date) {
                    Text("開催日", bundle: .module)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("会場(任意)", bundle: .module)
                        .font(.headline)
                    TextField(text: $model.venue) {
                        Text("市民体育館 など", bundle: .module)
                    }
                    .textFieldStyle(.roundedBorder)
                }

                entrySection
            }
            .padding()
        }
        .navigationTitle(model.isNew ? Text("大会を追加", bundle: .module) : Text("大会を編集", bundle: .module))
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
        .onAppear {
            model.load()
        }
    }

    /// §6 1 大会が複数種目を持てる。目標大会は種目ごとに 1 件。
    @ViewBuilder private var entrySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("出場する種目", bundle: .module)
                .font(.headline)

            Toggle(isOn: $model.entersSingles) {
                Text(Discipline.singles.displayName)
            }
            if model.entersSingles {
                Toggle(isOn: $model.singlesIsTarget) {
                    Text("シングルスの目標大会にする", bundle: .module)
                        .font(.footnote)
                }
                .padding(.leading, 16)
            }

            Toggle(isOn: $model.entersDoubles) {
                Text(Discipline.doubles.displayName)
            }
            if model.entersDoubles {
                Toggle(isOn: $model.doublesIsTarget) {
                    Text("ダブルスの目標大会にする", bundle: .module)
                        .font(.footnote)
                }
                .padding(.leading, 16)
            }

            Text("目標大会にすると、ホームにカウントダウンが出ます", bundle: .module)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
