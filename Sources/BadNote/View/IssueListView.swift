import SwiftUI

/// 課題一覧(§7.4)。
///
/// 3 層を縦に並べたセクションリスト。**タブにしない** —— 移動先が見えている必要がある。
/// 優先順位の変更は今のところタップによる層移動のみ(ドラッグとスワイプは後で足す)。
public struct IssueListView: View {
    @State private var model = IssueListModel()

    public init() {
    }

    public var body: some View {
        List {
            if let errorText = model.errorText {
                Text(errorText)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
            Section {
                filterRow
            }
            section(title: Text("今週の重点", bundle: .module),
                    count: Text(verbatim: "\(model.focus.count)/\(model.focusCapacity)"),
                    issues: model.focus)
            section(title: Text("次にやる", bundle: .module),
                    count: Text(verbatim: "\(model.next.count)件"),
                    issues: model.next)
            section(title: Text("いつか", bundle: .module),
                    count: Text(verbatim: "\(model.someday.count)件"),
                    issues: model.someday)
        }
        .navigationTitle(Text("課題", bundle: .module))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    IssueEditView()
                } label: {
                    Text("追加", bundle: .module)
                }
            }
            // §5.3 未整理の件数はバッジで出さない。導線だけ置く
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    InboxTriageView()
                } label: {
                    Text("整理", bundle: .module)
                }
            }
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

    /// §7.4 上部に 1 行。ショットタグ / 習熟度 / 種目。**既定はフィルタなし。**
    @ViewBuilder private var filterRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                Menu {
                    Button {
                        model.selectDiscipline(nil)
                    } label: {
                        Text("すべての種目", bundle: .module)
                    }
                    ForEach(Discipline.allCases, id: \.rawValue) { value in
                        Button {
                            model.selectDiscipline(value)
                        } label: {
                            Text(value.displayName)
                        }
                    }
                } label: {
                    filterLabel(model.discipline?.displayName, placeholder: Text("種目", bundle: .module))
                }

                Menu {
                    Button {
                        model.selectMasteryLevel(nil)
                    } label: {
                        Text("すべての習熟度", bundle: .module)
                    }
                    ForEach(MasteryLevel.allCases, id: \.rawValue) { value in
                        Button {
                            model.selectMasteryLevel(value)
                        } label: {
                            Text(value.displayName)
                        }
                    }
                } label: {
                    filterLabel(model.masteryLevel?.displayName, placeholder: Text("習熟度", bundle: .module))
                }

                if !model.availableTags.isEmpty {
                    Menu {
                        Button {
                            model.selectTag(nil)
                        } label: {
                            Text("すべてのタグ", bundle: .module)
                        }
                        ForEach(model.availableTags) { tag in
                            Button {
                                model.selectTag(tag.id)
                            } label: {
                                Text(tag.name)
                            }
                        }
                    } label: {
                        filterLabel(model.selectedTagName(), placeholder: Text("タグ", bundle: .module))
                    }
                }

                if model.isFiltering {
                    Button {
                        model.clearFilters()
                    } label: {
                        Text("解除", bundle: .module)
                    }
                    .buttonStyle(.bordered)
                    .font(.footnote)
                }
            }
        }
    }

    @ViewBuilder private func filterLabel(_ selected: String?, placeholder: Text) -> some View {
        if let selected = selected {
            Text(verbatim: selected)
                .font(.footnote)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.2))
                .cornerRadius(16)
        } else {
            placeholder
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(16)
        }
    }

    @ViewBuilder private func section(title: Text, count: Text, issues: [Issue]) -> some View {
        Section {
            if issues.isEmpty {
                Text("まだありません", bundle: .module)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(issues) { issue in
                row(issue)
            }
        } header: {
            HStack {
                title
                Spacer()
                count
            }
        }
    }

    /// §7.4 一覧を眺めながら次々に仕分ける用途に最速なので、スワイプで 1 段ずつ動かす。
    /// 右スワイプ(`.leading`)で上げ、左スワイプ(`.trailing`)で下げる。
    @ViewBuilder private func row(_ issue: Issue) -> some View {
        NavigationLink {
            IssueDetailView(issueID: issue.id)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(issue.displayTitle)
                    .font(.body)
                Text(issue.masteryLevel.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .swipeActions(edge: .leading) {
            if issue.tier.higher != nil {
                Button {
                    model.promote(issue)
                } label: {
                    Text("上げる", bundle: .module)
                }
            }
        }
        .swipeActions(edge: .trailing) {
            if issue.tier.lower != nil {
                Button {
                    model.demote(issue)
                } label: {
                    Text("下げる", bundle: .module)
                }
            }
        }
    }

}
