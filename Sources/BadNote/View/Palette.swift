import SwiftUI

/// 色の決めごと(tasks.md 1.1)。**View は色を直書きせず、ここから取る。**
///
/// ブランド色はインディゴ(light `#5C6BC0` / dark `#7986CB`)。値は 2 か所にある:
///
/// - `Darwin/Assets.xcassets/AccentColor.colorset` — iOS のアプリ全体の tint
/// - `Sources/BadNote/Resources/Module.xcassets/AccentColor.colorset` — Android。
///   SkipUI が `Bundle.main`(= このモジュールの `Resources/`)の `AccentColor` を見つけて
///   Material 3 の `primary` に自動適用するので、`material3ColorScheme` を手で書く必要はない。
///   **2 か所の値は同じに保つこと。**
///
/// 面と手応えの色は `Module.xcassets` の colorset(light / dark の 2 値)。
/// 色を変えるときはカタログの JSON だけ直せば、iOS / Android の両方に効く。
public struct Palette {
    /// ブランド色。ボタン・選択状態・押せる導線
    public static var accent: Color { Color.accentColor }
    /// カードの面
    public static var surface: Color { Color("SurfaceColor", bundle: .module) }
    /// カードの上に載るチップ・バッジ・帯の面
    public static var surfaceRaised: Color { Color("SurfaceRaisedColor", bundle: .module) }
    /// 手応え「できた」
    public static var done: Color { Color("DoneColor", bundle: .module) }
    /// 手応え「近づいた」
    public static var closer: Color { Color("CloserColor", bundle: .module) }
    /// 手応え「次にやる」
    public static var next: Color { Color("NextColor", bundle: .module) }

    private init() {
    }
}
