import Foundation

/// タグの候補を何行に分けて並べるか(2026-10-28)。
///
/// **`Grid` は SkipUI 非対応**なので、折り返しは自前で行に分ける。
/// 画面側で計算すると境界(0 件・端数)を間違えやすいので、ここに出してテストで固定する。
public enum TagChipRows {

    /// 1 行に並べる数。
    ///
    /// タグは短い言葉(「バックハンド」「フットワーク」)が多く、
    /// 3 つ並べると折り返さずに収まる幅になる。
    public static let perRow = 3

    /// 全部で何行になるか。0 件なら 0 行。
    public static func rowCount(of count: Int) -> Int {
        if count <= 0 {
            return 0
        }
        return (count + TagChipRows.perRow - 1) / TagChipRows.perRow
    }

    /// その行に入るタグ。**範囲外の行を渡されても落ちない**(空で返す)。
    public static func items(in tags: [Tag], row: Int) -> [Tag] {
        if row < 0 {
            return []
        }
        let start = row * TagChipRows.perRow
        if start >= tags.count {
            return []
        }
        var end = start + TagChipRows.perRow
        if end > tags.count {
            end = tags.count
        }
        var result: [Tag] = []
        for index in start..<end {
            result.append(tags[index])
        }
        return result
    }
}
