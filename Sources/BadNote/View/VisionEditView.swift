import SwiftUI

/// めざす姿の編集(§7.1)。
///
/// 4 層構造の頂点。大会に意味を与えるものなので、大会より上に置く。
public struct VisionEditView: View {
    @State private var model = VisionEditModel()
    @Environment(\.dismiss) private var dismiss

    public init() {
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let errorText = model.errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                // **何を書く場所かを先に決める**(1.8)。成績(「全国大会に出る」)を
                // ここに書くと、それを持つべき下の層(目標の大会 = 通過点・締め切り)と
                // 役割が重なって 4 層構造が崩れる
                Text("なりたい選手像を書きます。大会の結果ではなく「どんな選手か」で書きます", bundle: .module)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                // いちばん抽象的で書き出しにくい画面なので例を置く。
                // TextEditor はプレースホルダを持てないので、欄の上に出す(1.6 と同じ形)
                Text("例: 守りから攻めに切り替えるのが速い選手 / 終盤でも足が止まらない選手", bundle: .module)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextEditor(text: $model.body)
                    .frame(minHeight: 200)
                    .border(Color.secondary.opacity(0.4), width: 1)
                    .accessibilityIdentifier("vision-editor")

                Text("うまく言葉にできなければ、途中まででも構いません", bundle: .module)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle(Text("めざす姿", bundle: .module))
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    model.save()
                    if model.isSaved {
                        dismiss()
                    }
                } label: {
                    Text("保存", bundle: .module)
                        .accessibilityIdentifier("vision-save")
                }
            }
        }
        .onAppear {
            model.load()
        }
    }
}
