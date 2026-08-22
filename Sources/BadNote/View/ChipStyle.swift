import SwiftUI

/// 選択状態を持つチップ。行を均等に分け合う。
///
/// Android の Material ボタンは iOS より内側の余白が広く、日本語のラベルは
/// すぐ 2 行に割れる(「全体練 習」)。幅が足りないときは折り返す代わりに
/// 少しだけ縮める。縮小は 0.8 倍までなので、それでも入らない長さのラベルは
/// 1 行に並べる個数を減らすこと。
///
/// **`.frame(maxWidth: .infinity)` はボタンとラベルの両方に要る。**
/// ボタンだけに付けると、枠は広がらずに中央へ寄るだけで、幅がばらついて見える。
struct SelectableChip: View {
    let label: Text
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        if isSelected {
            Button(action: action) {
                label
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .chipLabelFit()
            .frame(maxWidth: .infinity)
        } else {
            Button(action: action) {
                label
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .chipLabelFit()
            .frame(maxWidth: .infinity)
        }
    }
}

extension View {
    /// ラベルを折り返さず、入り切らなければ少しだけ縮める。
    ///
    /// `lineLimit` も `minimumScaleFactor` も環境値なので、ボタンに付ければ
    /// 中のラベルまで届く。
    func chipLabelFit() -> some View {
        return self
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}
