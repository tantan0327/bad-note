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
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let errorText = model.errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundStyle(.red)
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
            .padding()
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

    @ViewBuilder private func section(title: Text, count: Text, issues: [Issue]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                title.font(.headline)
                Spacer()
                count
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if issues.isEmpty {
                Text("まだありません", bundle: .module)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(issues) { issue in
                row(issue)
            }
        }
    }

    @ViewBuilder private func row(_ issue: Issue) -> some View {
        HStack(spacing: 8) {
            NavigationLink {
                IssueEditView(issueID: issue.id)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(issue.displayTitle)
                        .font(.body)
                    Text(issue.masteryLevel.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if issue.tier.higher != nil {
                Button {
                    model.promote(issue)
                } label: {
                    Text("上げる", bundle: .module).font(.caption)
                }
                .buttonStyle(.bordered)
            }
            if issue.tier.lower != nil {
                Button {
                    model.demote(issue)
                } label: {
                    Text("下げる", bundle: .module).font(.caption)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }

}
