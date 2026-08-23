import SwiftUI

/// カード内の統計数字(数字 + 単位 + ラベル)。
///
/// 積み上げ画面の 2 スタットと課題詳細の「記録」で**同じ形**を使う(tasks.md 2.2)。
/// 数字 22pt semibold、単位とラベルは `.caption`(文字の段階の表)。
struct StatItem: View {
    let value: Int
    let unit: Text
    let label: Text

    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(verbatim: "\(value)")
                    .font(.system(size: 22, weight: .semibold))
                unit
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            label
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel(label)
        .accessibilityValue(Text(verbatim: "\(value)"))
    }
}
