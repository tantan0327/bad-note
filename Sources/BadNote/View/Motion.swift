import SwiftUI

/// 動きの決めごと(tasks.md 5.1)。**選択は速く、移動はゆっくり。**
///
/// View で duration を直書きせず、ここから取る(色の `Palette` と同じ考え方)。
struct Motion {
    /// チップの選択・チェック・バーの伸び縮みなど、指先への反応。速く小さく
    static let select = Animation.easeOut(duration: 0.15)
    /// 行の移動・出入り・画面の切り替わり。位置の変化を目で追える速さ
    static let move = Animation.easeInOut(duration: 0.3)

    private init() {
    }
}
