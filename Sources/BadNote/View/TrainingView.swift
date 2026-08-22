import SwiftUI

/// 家トレ(§10.2)。その日のメニューをチェックする毎日のリスト。
///
/// 同じ形の行を選ぶだけの画面なので `List`(区切り線の決めごと)。
/// **残り件数は出さない**(§5.3)。出すのはチェックが付いた分の合計だけ。
public struct TrainingView: View {
    @State private var model = TrainingModel()

    public init() {
    }

    public var body: some View {
        List {
            dateSection
            if let errorText = model.errorText {
                Text(errorText)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
            if model.menus.isEmpty {
                emptySection
            } else {
                menuSection
            }
        }
        .navigationTitle(Text("家トレ", bundle: .module))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    TrainingMenuListView()
                } label: {
                    Text("メニュー", bundle: .module)
                }
                .accessibilityIdentifier("training_menu_button")
            }
        }
        .onAppear {
            model.load()
        }
        .onChange(of: model.date) { _, _ in
            model.load()
        }
    }

    // MARK: - 日付(さかのぼって付けられる)

    @ViewBuilder private var dateSection: some View {
        Section {
            DatePicker(selection: $model.date, displayedComponents: .date) {
                Text("日付", bundle: .module)
            }
            .accessibilityIdentifier("training_date_picker")
            if !model.isToday {
                Button {
                    model.backToToday()
                } label: {
                    Text("今日に戻る", bundle: .module)
                        .font(.footnote)
                }
                .accessibilityIdentifier("training_back_to_today")
            }
        }
    }

    // MARK: - メニュー

    @ViewBuilder private var menuSection: some View {
        Section {
            ForEach(model.menus) { menu in
                menuRow(menu)
            }
        } footer: {
            // §5.3 チェックが付いた分だけが見える。残り件数は出さない
            if model.doneMinutes > 0 {
                Text(verbatim: model.isToday
                     ? "今日の家トレ \(model.doneMinutes) 分"
                     : "この日の家トレ \(model.doneMinutes) 分")
            }
        }
    }

    @ViewBuilder private func menuRow(_ menu: TrainingMenu) -> some View {
        Button {
            model.toggle(menu)
        } label: {
            HStack(spacing: 12) {
                // 済 / 未 は色 + 形(チェック入りの丸 / 空の輪)で区別する
                Image(model.isDone(menu) ? "check_circle" : "circle", bundle: .module)
                    .foregroundStyle(model.isDone(menu) ? Palette.done : Color.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(menu.name)
                        .font(.body)
                    if let minutes = menu.minutes {
                        Text(verbatim: "\(minutes) 分")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            // 本文なのでリンク色にしない(現状: リンク色の扱い)
            .foregroundStyle(.primary)
        }
        .accessibilityIdentifier("training_row_\(menu.id)")
    }

    // MARK: - 空の状態

    @ViewBuilder private var emptySection: some View {
        Section {
            Text("メニューはまだありません。素振り 50 回、体幹 10 分のように、毎日やる形で決めておきます", bundle: .module)
                .font(.footnote)
                .foregroundStyle(.secondary)
            NavigationLink {
                TrainingMenuListView()
            } label: {
                Text("メニューを作る", bundle: .module)
            }
            .accessibilityIdentifier("training_create_menu")
        }
    }
}
