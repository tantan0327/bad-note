import Foundation

/// めざす姿(§6 `vision`)。なりたい選手像。レコードは常に 1 件。
///
/// 未保存でも `VisionRepository.fetch()` は nil ではなくこの型の空の値を返す。
/// 「まだ無い」を呼び出し側で分岐させないための設計。
public struct Vision: Hashable {
    public var body: String
    /// 任意の画像 1 枚(§7.1)
    public var imagePath: String?
    /// 一度も保存していなければ nil。
    /// §7.1「初回は促さない。数回使った後に 1 度だけ促す」の判断材料になる。
    public var updatedAt: Date?

    public init(body: String = "", imagePath: String? = nil, updatedAt: Date? = nil) {
        self.body = body
        self.imagePath = imagePath
        self.updatedAt = updatedAt
    }

    /// 本文も画像も無い状態。§7.1「めざす姿が空」の判定。
    ///
    /// 保存済みかどうかとは別。空のまま保存し直すこともある。
    public var isEmpty: Bool {
        return body.isEmpty && imagePath == nil
    }
}
