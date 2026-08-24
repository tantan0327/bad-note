import SwiftUI

/// メニューの管理(§10.2)。追加・編集・並び替え(長押しドラッグ)。
struct TrainingMenuListView: View {
    @State private var model = TrainingMenuModel()

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
                    .accessibilityIdentifier("training_menu_empty_action")
                }
            }
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
                .accessibilityIdentifier("training_menu_row_\(menu.id)")
            }
            .onMove { offsets, toOffset in
                model.move(from: Array(offsets), to: toOffset)
            }
        }
        .navigationTitle(Text("メニュー", bundle: .module))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    TrainingMenuFormView(menuID: nil)
                } label: {
                    Text("追加", bundle: .module)
                }
                .accessibilityIdentifier("training_menu_add")
            }
        }
        .onAppear {
            model.load()
        }
    }
}
