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

                Text("なりたい選手像を書きます", bundle: .module)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                TextEditor(text: $model.body)
                    .frame(minHeight: 200)
                    .border(Color.secondary.opacity(0.4), width: 1)

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
                }
            }
        }
        .onAppear {
            model.load()
        }
    }
}
