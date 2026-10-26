import SwiftUI

/// 空の状態(tasks.md 2.4)。**灰色 1 行で済ませない。**
///
/// アイコン(任意)+ 一言 + 次の 1 手のボタン(任意)を中央に積む。
/// 「次の 1 手」が無い画面 —— 記録が増えるのを待つだけの場所や、
/// **めざす姿のように促さないと決めた場所(§7.1)** ではボタンを省き、
/// `action` に `{ EmptyView() }` を渡す。
///
/// ボタンは呼び出し側が渡す。`NavigationLink`(プッシュ)でも `Button`(シート等)でも
/// 置けるよう `@ViewBuilder` で受ける。`.buttonStyle(.borderedProminent)` は
/// 呼び出し側で当てる(押す先によって適切な種類が変わるため)。
struct EmptyStateView<Action: View>: View {
    private let iconName: String?
    private let message: Text
    private let action: Action

    init(icon iconName: String? = nil, message: Text, @ViewBuilder action: () -> Action) {
        self.iconName = iconName
        self.message = message
        self.action = action()
    }

    var body: some View {
        VStack(spacing: 12) {
            if let iconName = iconName {
                // **読み上げない。** 絵は下の文の飾りで、文が同じことを言っている(6.1)
                Image(iconName, bundle: .module)
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            message
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            action
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}
