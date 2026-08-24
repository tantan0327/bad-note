import SwiftUI

/// メニューの管理(§10.2)。追加・編集・並び替え(長押しドラッグ)。
/// アーカイブ済みは末尾の折りたたみから戻せる(3.5)。
struct TrainingMenuListView: View {
    @State private var model = TrainingMenuModel()
    @State private var isShowingArchived = false

    var body: some View {
        List {
            if let errorText = model.errorText {
                Text(errorText)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
            if model.menus.isEmpty {
                // 空の状態も 2.4 の形に。次の 1 手はその場からフォームへ(3.4)
                EmptyStateView(icon: "fitness_center",
                               message: Text("メニューはまだありません", bundle: .module)) {
                    NavigationLink {
                        TrainingMenuFormView(menuID: nil)
                    } label: {
                        Text("メニューを追加する", bundle: .module)
                            .font(.footnote)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("training-menu-empty-action")
                }
            }
            Section {
                ForEach(model.menus) { menu in
                    NavigationLink {
                        TrainingMenuFormView(menuID: menu.id)
                    } label: {
                        HStack {
                            Text(menu.name)
                            Spacer()
                            if let minutes = menu.minutes {
                                Text(verbatim: "\(minutes) 分")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .accessibilityIdentifier("training-menu-row-\(menu.id)")
                }
                .onMove { offsets, toOffset in
                    model.move(from: Array(offsets), to: toOffset)
                }
            } footer: {
                // 4.3 並び替えの手がかり。2 行以上あるときだけ添える
                if model.menus.count > 1 {
                    Text("行は長押しで並び替えられます", bundle: .module)
                }
            }
            archivedSection
        }
        .navigationTitle(Text("メニュー", bundle: .module))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    TrainingMenuFormView(menuID: nil)
                } label: {
                    Text("追加", bundle: .module)
                }
                .accessibilityIdentifier("training-menu-add")
            }
        }
        .onAppear {
            model.load()
        }
    }

    // MARK: - アーカイブ済み(3.5。折りたたみ。行から戻せる)

    @ViewBuilder private var archivedSection: some View {
        if !model.archivedMenus.isEmpty {
            Section {
                Button {
                    isShowingArchived = !isShowingArchived
                } label: {
                    Text(isShowingArchived ? "アーカイブ済みを閉じる" : "アーカイブ済みを見る", bundle: .module)
                        .font(.footnote)
                }
                .accessibilityIdentifier("training-archived-toggle")
                if isShowingArchived {
                    ForEach(model.archivedMenus) { menu in
                        Button {
                            model.restore(menu)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(menu.name)
                                        .foregroundStyle(.secondary)
                                    if let minutes = menu.minutes {
                                        Text(verbatim: "\(minutes) 分")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                // 押せる導線はリンク色(2.3 と同じ形)
                                Text("戻す", bundle: .module)
                                    .font(.footnote)
                                    .foregroundStyle(Palette.accent)
                            }
                            .foregroundStyle(.primary)
                        }
                        .accessibilityIdentifier("training-archived-row-\(menu.id)")
                    }
                }
            } footer: {
                if isShowingArchived {
                    Text("戻すと一覧に並び直します。過去の記録はそのまま残っています", bundle: .module)
                }
            }
        }
    }
}
