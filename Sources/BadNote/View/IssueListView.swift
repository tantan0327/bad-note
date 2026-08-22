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
            // §7.4 層をまたぐドラッグのため、3 層を 1 つの ForEach に畳んでいる
            ForEach(model.rows) { row in
                if row.isHeader {
                    headerRow(row.tier)
                } else if row.isPlaceholder {
                    emptyRow
                } else if let issue = row.issue {
                    self.row(issue)
                }
            }
            .onMove { offsets, toOffset in
                model.moveRows(from: Array(offsets), to: toOffset)
            }
            Section {
                NavigationLink {
                    FocusReshuffleView()
                } label: {
                    Text("今週の重点を組み替える", bundle: .module)
                        .font(.footnote)
                }
            }
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
                .background(Palette.accent.opacity(0.2))
                .cornerRadius(16)
        } else {
            placeholder
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Palette.surface)
                .cornerRadius(16)
        }
    }

    /// 空の層の行。**`moveDisabled` を付けない** ——
    /// これがドラッグの落とし先になる(付けると空の層に移動できなくなる)。
    @ViewBuilder private var emptyRow: some View {
        Text("まだありません", bundle: .module)
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    /// 層の見出し。ドラッグの落下位置を決める区切りでもあるので、行として並べる。
    @ViewBuilder private func headerRow(_ tier: Tier) -> some View {
        HStack {
            Text(tierName(tier))
                .font(.headline)
            Spacer()
            Text(verbatim: tier == Tier.focus
                 ? "\(model.count(of: tier))/\(model.focusCapacity)"
                 : "\(model.count(of: tier))件")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
        .moveDisabled(true)
    }

    private func tierName(_ tier: Tier) -> String {
        switch tier {
        case .focus: return "今週の重点"
        case .next: return "次にやる"
        case .someday: return "いつか"
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
