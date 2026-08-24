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
        // 3.1 チェックの手触り。ふだんは選択の軽い振動、その日の分が全部
        // 済んだ瞬間だけ成功の振動。日付の切り替えでは鳴らない(トリガーは操作回数)
        .sensoryFeedback(trigger: model.toggleCount) { _, _ in
            model.isAllDone ? SensoryFeedback.success : SensoryFeedback.selection
        }
    }

    // MARK: - 日付(「今日」が画面の顔。さかのぼりは控えめに。3.2)

    @ViewBuilder private var dateSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: model.dayTitle)
                        .font(.title2)
                    Text(verbatim: model.daySubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if model.isToday {
                    // 付け忘れの大半は昨日の分。1 タップでさかのぼる
                    Button {
                        model.selectYesterday()
                    } label: {
                        Text("昨日", bundle: .module)
                            .font(.footnote)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("training_select_yesterday")
                } else {
                    // 過去日を開いていることが見た目でも分かるように、戻る導線を目立たせる
                    Button {
                        model.backToToday()
                    } label: {
                        Text("今日に戻る", bundle: .module)
                            .font(.footnote)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("training_back_to_today")
                }
            }
            // 昨日より前は控えめな行から
            DatePicker(selection: $model.date, displayedComponents: .date) {
                Text("別の日", bundle: .module)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("training_date_picker")
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
            if model.isAllDone {
                // 3.1 全部できた日の静かな強調。件数もストリークも出さない
                Text(verbatim: footerText() + " ✓")
                    .foregroundStyle(Palette.done)
            } else if model.doneMinutes > 0 {
                Text(verbatim: footerText())
            }
        }
    }

    private func footerText() -> String {
        let day = model.isToday ? "今日" : "この日"
        // 分数の無いメニューだけの日は 0 分表記を出さない(チェックの事実だけ祝う)
        if model.doneMinutes > 0 {
            return "\(day)の家トレ \(model.doneMinutes) 分"
        }
        return "\(day)の家トレ"
    }

    @ViewBuilder private func menuRow(_ menu: TrainingMenu) -> some View {
        Button {
            // 3.1 速く小さく動かす(フッターの合計の出入りも一緒に animate される)
            withAnimation(Motion.select) {
                model.toggle(menu)
            }
        } label: {
            HStack(spacing: 12) {
                // 済 / 未 は色 + 形(チェック入りの丸 / 空の輪)で区別する
                Image(model.isDone(menu) ? "check_circle" : "circle", bundle: .module)
                    .foregroundStyle(model.isDone(menu) ? Palette.done : Color.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    // 済んだ行は名前を沈めて「あとどれか」を読めるように(3.3)。
                    // 消し込み線は「作業を消す」感が強いので使わない
                    Text(menu.name)
                        .font(.body)
                        .foregroundStyle(model.isDone(menu) ? Color.secondary : Color.primary)
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
        // VoiceOver にも済 / まだが伝わるように(3.3)
        .accessibilityValue(model.isDone(menu) ? Text("済", bundle: .module) : Text("まだ", bundle: .module))
    }

    // MARK: - 空の状態

    @ViewBuilder private var emptySection: some View {
        Section {
            // 最初の 1 個への道は 1 タップ(3.4)。空の一覧を経由せず直接フォームへ
            EmptyStateView(icon: "fitness_center",
                           message: Text("メニューはまだありません。素振り 50 回、体幹 10 分のように、毎日やる形で決めておきます", bundle: .module)) {
                NavigationLink {
                    TrainingMenuFormView(menuID: nil)
                } label: {
                    Text("メニューを作る", bundle: .module)
                        .font(.footnote)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("training_create_menu")
            }
        }
    }
}
