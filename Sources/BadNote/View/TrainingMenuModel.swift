import Foundation
import Observation
import SkipSQL

/// メニュー管理画面の状態(§10.2)。一覧と並び替えを担当する。
@Observable public final class TrainingMenuModel {
    public private(set) var menus: [TrainingMenu] = []
    /// アーカイブ済み(3.5)。折りたたみの中でだけ見せる。
    public private(set) var archivedMenus: [TrainingMenu] = []
    public var errorText: String? = nil

    private var database: SQLContext? = nil

    public init() {
    }

    public func load() {
        do {
            let db = try context()
            let all = try TrainingRepository(db: db).fetchMenus(includeArchived: true)
            var active: [TrainingMenu] = []
            var archived: [TrainingMenu] = []
            for menu in all {
                if menu.isArchived {
                    archived.append(menu)
                } else {
                    active.append(menu)
                }
            }
            menus = active
            archivedMenus = archived
            errorText = nil
        } catch {
            errorText = "メニューの読み込みに失敗しました: \(error)"
        }
    }

    /// アーカイブから一覧に戻す(3.5)。実施記録はそのまま(§10.2)。
    public func restore(_ menu: TrainingMenu) {
        do {
            let db = try context()
            var updated = menu
            updated.isArchived = false
            _ = try TrainingRepository(db: db).updateMenu(updated)
            load()
            errorText = nil
        } catch {
            errorText = "戻すのに失敗しました: \(error)"
        }
    }

    /// 並び替え(長押しドラッグ)。並べ直した順で sort_order を振り直す。
    ///
    /// `onMove` が運ぶのは 1 行だけなので、先頭の offset だけ見る(`IssueListModel` と同じ)。
    public func move(from offsets: [Int], to destination: Int) {
        guard let fromOffset = offsets.first, fromOffset < menus.count else {
            return
        }
        var reordered = menus
        let menu = reordered.remove(at: fromOffset)
        let target = fromOffset < destination ? destination - 1 : destination
        reordered.insert(menu, at: min(max(target, 0), reordered.count))

        do {
            let db = try context()
            var ids: [Int64] = []
            for menu in reordered {
                ids.append(menu.id)
            }
            try TrainingRepository(db: db).reorderMenus(ids: ids)
            menus = reordered
            errorText = nil
        } catch {
            errorText = "並び替えに失敗しました: \(error)"
        }
    }

    private func context() throws -> SQLContext {
        if let database = database {
            return database
        }
        let opened = try AppDatabase.open()
        database = opened
        return opened
    }
}
