import SwiftUI

/// バッジ(表示のみ。tasks.md 2.3)。
///
/// 形は「現状」の面と余白の表 —— `.caption` / 横 8 縦 4 / 角丸 4 / `Palette.surfaceRaised`。
/// **押せる部品には使わない**(押せるのはピルかボタン)。
struct Badge: View {
    let label: Text
    /// 文字色。面は `surfaceRaised` のまま変えず、**意味の違いは文字色だけで出す**
    /// (面まで色を付けると一覧が騒がしくなる。2026-08-25)。
    let tint: Color

    init(label: Text, tint: Color = Color.primary) {
        self.label = label
        self.tint = tint
    }

    var body: some View {
        label
            .font(.caption)
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Palette.surfaceRaised)
            .cornerRadius(4)
    }
}

extension PriorityHint {
    /// 目印の文字色(§3.4)。**重点に入れるべき候補だけ目を引かせる。**
    /// シーズン単位は知らせるだけなので、控えめにして焦らせない。
    var tint: Color {
        switch self {
        case .quickWin: return Palette.accent
        case .seasonLong: return Color.secondary
        }
    }
}
