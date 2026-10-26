import SwiftUI

/// メニューの追加・編集フォーム(§10.2)。
///
/// 目安の分数は入力を勧めるが必須にしない。メニューは削除ではなくアーカイブ。
struct TrainingMenuFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: TrainingMenuFormModel

    // 数字キーボードを閉じる手段(iOS のみ)。Android はシステムの戻るで閉じる
    #if os(iOS)
    @FocusState private var isMinutesFocused: Bool
    #endif

    init(menuID: Int64?) {
        _model = State(initialValue: TrainingMenuFormModel(menuID: menuID))
    }

    var body: some View {
        Form {
            if let errorText = model.errorText {
                Text(errorText)
                    .font(.footnote)
                    .foregroundStyle(Palette.error)
            }
            Section {
                TextField(text: $model.name) {
                    Text("素振り 50 回、体幹 10 分 など", bundle: .module)
                }
                .accessibilityIdentifier("training-menu-name")
            } header: {
                Text("メニュー", bundle: .module)
            }
            Section {
                TextField(text: $model.minutesText) {
                    Text("分数(任意)", bundle: .module)
                }
                #if os(iOS) || os(Android)
                .keyboardType(.numberPad)
                #endif
                #if os(iOS)
                .focused($isMinutesFocused)
                #endif
                .accessibilityIdentifier("training-menu-minutes")
            } header: {
                Text("目安の時間", bundle: .module)
            } footer: {
                Text("チェックしたとき、この分数が練習時間の積み上げに入ります", bundle: .module)
            }
            Section {
                Button {
                    if model.save() {
                        dismiss()
                    }
                } label: {
                    Text("保存", bundle: .module)
                }
                .disabled(!model.canSave)
                .accessibilityIdentifier("training-menu-save")
            } footer: {
                // 灰色の保存を見ても、何が足りないのかは分からない
                if !model.canSave {
                    Text("メニュー名を入れると保存できます", bundle: .module)
                }
            }
            if !model.isNew {
                Section {
                    Button {
                        if model.archive() {
                            dismiss()
                        }
                    } label: {
                        Text("アーカイブする", bundle: .module)
                    }
                    .accessibilityIdentifier("training-menu-archive")
                } footer: {
                    Text("一覧から消えます。過去の記録は残ります", bundle: .module)
                }
            }
        }
        .navigationTitle(model.isNew ? Text("メニューを追加", bundle: .module) : Text("メニューを編集", bundle: .module))
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
                    .accessibilityIdentifier("training-menu-minutes-done")
                }
            }
        }
        #endif
        .onAppear {
            model.load()
        }
    }
}
