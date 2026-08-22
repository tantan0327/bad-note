import SwiftUI

/// カード(tasks.md 1.3)。角丸・内側の余白・面の色をここで 1 回だけ決める。
///
/// - 面は `Palette.surface` / 内側の余白 12 / 角丸 8 / 幅いっぱい・左寄せ
/// - 強調したい帯は `Card(background: Palette.surfaceRaised)`
/// - View 側で `.padding(12)` + `.background` + `.cornerRadius` を並べて書かない
struct Card<Content: View>: View {
    private let background: Color
    private let content: Content

    init(background: Color = Palette.surface, @ViewBuilder content: () -> Content) {
        self.background = background
        self.content = content()
    }

    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .cornerRadius(8)
    }
}
