import SwiftUI

/// バッジ(表示のみ。tasks.md 2.3)。
///
/// 形は「現状」の面と余白の表 —— `.caption` / 横 8 縦 4 / 角丸 4 / `Palette.surfaceRaised`。
/// **押せる部品には使わない**(押せるのはピルかボタン)。
struct Badge: View {
    let label: Text

    var body: some View {
        label
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Palette.surfaceRaised)
            .cornerRadius(4)
    }
}
