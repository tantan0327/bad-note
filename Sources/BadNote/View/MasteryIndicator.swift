import SwiftUI

/// 行に置く習熟度(ミニ 4 分割バー + 段階名。tasks.md 2.3)。
///
/// 課題詳細の習熟度バー(§7.3)の縮小版。文字だけに頼らず、
/// 埋まった数で進み具合がひと目で分かる(色 + 形)。
struct MasteryIndicator: View {
    let level: MasteryLevel

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(MasteryLevel.allCases, id: \.rawValue) { step in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(step.rawValue <= level.rawValue ? Palette.accent : Palette.surfaceRaised)
                        .frame(width: 10, height: 4)
                }
            }
            Text(level.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityLabel(Text("習熟度", bundle: .module))
        .accessibilityValue(Text(verbatim: "\(level.rawValue)/4 \(level.displayName)"))
    }
}
