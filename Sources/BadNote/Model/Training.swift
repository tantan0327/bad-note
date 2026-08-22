import Foundation

/// メニュー(§10.1 `training_menu`)。繰り返しやる家トレの決めごと。
public struct TrainingMenu: Hashable, Identifiable {
    public var id: Int64
    public var name: String
    /// 目安の分数。任意(§10.1)。チェック時にこの値が実施記録へ写る
    public var minutes: Int?
    public var sortOrder: Int
    /// 削除ではなくアーカイブ(§10.2)。過去の実施記録を守る
    public var isArchived: Bool
    public var createdAt: Date

    public init(id: Int64,
                name: String,
                minutes: Int? = nil,
                sortOrder: Int = 0,
                isArchived: Bool = false,
                createdAt: Date) {
        self.id = id
        self.name = name
        self.minutes = minutes
        self.sortOrder = sortOrder
        self.isArchived = isArchived
        self.createdAt = createdAt
    }
}

/// 実施記録(§10.1 `training_log`)。日 × メニューで 1 行。
public struct TrainingLog: Hashable, Identifiable {
    public var id: Int64
    public var menuId: Int64
    /// ローカルの暦日の TEXT(`2026-08-22`)。タイムスタンプではない(§10.4)
    public var trainingDate: String
    /// チェック時点の分数の写し(§10.3)。nil は 0 分として積み上げに入る
    public var minutes: Int?
    public var doneAt: Date?

    public init(id: Int64,
                menuId: Int64,
                trainingDate: String,
                minutes: Int? = nil,
                doneAt: Date? = nil) {
        self.id = id
        self.menuId = menuId
        self.trainingDate = trainingDate
        self.minutes = minutes
        self.doneAt = doneAt
    }
}
