import SwiftUI

/// 家トレ(§10.2)。その日のメニューをチェックする毎日のリスト。
///
/// 同じ形の行を選ぶだけの画面なので `List`(区切り線の決めごと)。
/// **残り件数は出さない**(§5.3)。出すのはチェックが付いた分の合計だけ。
public struct TrainingView: View {
    @State private var model = TrainingModel()
    @State private var isEditingMinutes = false

    // 数字キーボードを閉じる手段(iOS のみ)。Android はシステムの戻るで閉じる。
    // SkipUI は `.keyboard` 配置をナビゲーションバーに流すので、iOS だけに出す
    #if os(iOS)
    @FocusState private var isMinutesFocused: Bool
    #endif

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
                .accessibilityIdentifier("training-menu-button")
            }
        }
        .onAppear {
            model.load()
        }
        .onChange(of: model.date) { _, _ in
            model.load()
        }
        // 3.1 チェックの手触り。ふだんは選択の軽い振動、その日の分が全部済んだ瞬間と
        // 節目を越えた瞬間(§10.5)だけ成功の振動。日付の切り替えでは鳴らない(トリガーは操作回数)
        .sensoryFeedback(trigger: model.toggleCount) { _, _ in
            (model.isAllDone || !model.reachedMilestones.isEmpty)
                ? SensoryFeedback.success
                : SensoryFeedback.selection
        }
        .sheet(isPresented: $isEditingMinutes) {
            minutesEditor
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
                    .accessibilityIdentifier("training-select-yesterday")
                } else {
                    // 過去日を開いていることが見た目でも分かるように、戻る導線を目立たせる
                    Button {
                        model.backToToday()
                    } label: {
                        Text("今日に戻る", bundle: .module)
                            .font(.footnote)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("training-back-to-today")
                }
            }
            // 昨日より前は控えめな行から
            DatePicker(selection: $model.date, displayedComponents: .date) {
                Text("別の日", bundle: .module)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("training-date-picker")
        }
    }

    // MARK: - メニュー

    @ViewBuilder private var menuSection: some View {
        Section {
            ForEach(model.menus) { menu in
                menuRow(menu)
            }
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                // 節目を越えた瞬間の静かな祝い(§10.5)。外すか画面を離れると消える
                ForEach(model.reachedMilestones, id: \.self) { hours in
                    Text(verbatim: "\(hours) 時間にとどきました")
                        .foregroundStyle(Palette.accent)
                }
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
        // チェックと分数チップの 2 つのボタンを**兄弟**に並べる(入れ子は片方が押せなくなる)。
        // List の既定スタイルのままだと行タップが両方に届くので、それぞれ明示する
        HStack(spacing: 12) {
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
                        // 未チェックの行は目安。チェック済みはこの日の分数がチップに出る
                        if !model.isDone(menu), let minutes = menu.minutes {
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
            .buttonStyle(.plain)
            .accessibilityIdentifier("training-row-\(menu.id)")
            // VoiceOver にも済 / まだが伝わるように(3.3)
            .accessibilityValue(model.isDone(menu) ? Text("済", bundle: .module) : Text("まだ", bundle: .module))

            // この日の分数(§10.3 の写し)。日によって時間が変わるので、その場で直せる。
            // 目安も分数も無いメニュー(回数もの)には出さない
            if model.isDone(menu), let log = model.logs[menu.id],
               log.minutes != nil || menu.minutes != nil {
                Button {
                    model.beginEditingMinutes(menu)
                    isEditingMinutes = true
                } label: {
                    if let minutes = log.minutes {
                        Text(verbatim: "\(minutes) 分")
                            .font(.caption)
                    } else {
                        Text("分を記録", bundle: .module)
                            .font(.caption)
                    }
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("training-minutes-\(menu.id)")
                .accessibilityLabel(Text("この日の分数", bundle: .module))
            }
        }
    }

    // MARK: - この日の分数の編集

    @ViewBuilder private var minutesEditor: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let menu = model.editingMenu {
                        Text(menu.name)
                            .font(.headline)
                    }
                    // 練習ログの練習時間と同じ形(表示と入力を 1 つに。§7.2)
                    HStack(spacing: 8) {
                        TextField(text: $model.editingMinutesText) {
                            Text(verbatim: "0")
                        }
                        .font(.system(size: 52, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 150)
                        #if os(iOS) || os(Android)
                        .keyboardType(.numberPad)
                        #endif
                        #if os(iOS)
                        .focused($isMinutesFocused)
                        #endif
                        .accessibilityIdentifier("training-minutes-field")
                        Text("分", bundle: .module)
                            .font(.title3)
                        Spacer()
                    }
                    HStack(spacing: 8) {
                        editorChip(Text("+5分", bundle: .module), amount: 5)
                        editorChip(Text("+10分", bundle: .module), amount: 10)
                        editorChip(Text("+15分", bundle: .module), amount: 15)
                        Spacer()
                        Button {
                            model.resetEditingMinutes()
                        } label: {
                            Text("リセット", bundle: .module)
                        }
                        .buttonStyle(.borderless)
                        .chipLabelFit()
                    }
                    if let minutes = model.editingDefaultMinutes {
                        Button {
                            model.resetEditingMinutesToDefault()
                        } label: {
                            Text(verbatim: "目安の \(minutes) 分に戻す")
                                .font(.footnote)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityIdentifier("training-minutes-default")
                    }
                }
                .padding()
            }
            .navigationTitle(model.isToday
                             ? Text("今日の分数", bundle: .module)
                             : Text("この日の分数", bundle: .module))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        model.cancelEditingMinutes()
                        isEditingMinutes = false
                    } label: {
                        Text("閉じる", bundle: .module)
                    }
                    .accessibilityIdentifier("training-minutes-close")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        // フッターの合計とチップの数字が一緒に動く(5.1)
                        withAnimation(Motion.select) {
                            model.saveEditedMinutes()
                        }
                        isEditingMinutes = false
                    } label: {
                        Text("保存", bundle: .module)
                    }
                    .accessibilityIdentifier("training-minutes-save")
                }
            }
            #if os(iOS)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    if isMinutesFocused {
                        Spacer()
                        Button {
                            isMinutesFocused = false
                        } label: {
                            Text("完了", bundle: .module)
                        }
                        .accessibilityIdentifier("training-minutes-done")
                    }
                }
            }
            #endif
        }
        .presentationDetents([.medium])
    }

    @ViewBuilder private func editorChip(_ label: Text, amount: Int) -> some View {
        Button {
            model.addEditingMinutes(amount)
        } label: {
            label
        }
        .buttonStyle(.bordered)
        .chipLabelFit()
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
                .accessibilityIdentifier("training-create-menu")
            }
        }
    }
}
