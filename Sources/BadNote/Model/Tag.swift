import Foundation

/// タグ(§6 `tag`)。ショット種別など、課題を横断して束ねるラベル。
///
/// 名前は UNIQUE。同じ名前のタグが 2 つ存在することはない。
public struct Tag: Hashable, Identifiable {
    public var id: Int64
    public var name: String

    public init(id: Int64, name: String) {
        self.id = id
        self.name = name
    }
}
