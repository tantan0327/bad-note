import Foundation
import Observation
import SkipSQL

/// メニューの追加・編集フォームの状態(§10.2)。
///
/// 目安の分数は**勧めるが必須にしない**(§10.2)。空なら nil で保存する。
@Observable public final class TrainingMenuFormModel {
    private let menuID: Int64?

    public var name = ""
    /// 数字以外が入ったら保存時に nil 扱い(必須にしない)
    public var minutesText = ""
    public var errorText: String? = nil


    public init(menuID: Int64?) {
        self.menuID = menuID
    }

    public var isNew: Bool {
        return menuID == nil
    }

    /// 名前が空のメニューは押しようがないので保存できない。
    public var canSave: Bool {
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public func load() {
        guard let menuID = menuID else {
            return
        }
        do {
            let db = try context()
            guard let menu = try TrainingRepository(db: db).fetchMenu(id: menuID) else {
                return
            }
            name = menu.name
            if let minutes = menu.minutes {
                minutesText = "\(minutes)"
            }
            errorText = nil
        } catch {
            errorText = "メニューの読み込みに失敗しました: \(error)"
        }
    }

    /// 保存できたら true(呼び出し側で閉じる)。
    public func save() -> Bool {
        do {
            let db = try context()
            let repo = TrainingRepository(db: db)
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let minutes = parsedMinutes()
            if let menuID = menuID {
                guard var menu = try repo.fetchMenu(id: menuID) else {
                    return false
                }
                menu.name = trimmed
                menu.minutes = minutes
                _ = try repo.updateMenu(menu)
            } else {
                _ = try repo.createMenu(name: trimmed, minutes: minutes)
            }
            errorText = nil
            return true
        } catch {
            errorText = "保存に失敗しました: \(error)"
            return false
        }
    }

    /// アーカイブできたら true(§10.2 削除ではなくアーカイブ)。
    public func archive() -> Bool {
        guard let menuID = menuID else {
            return false
        }
        do {
            let db = try context()
            try TrainingRepository(db: db).archiveMenu(id: menuID)
            errorText = nil
            return true
        } catch {
            errorText = "アーカイブに失敗しました: \(error)"
            return false
        }
    }

    private func parsedMinutes() -> Int? {
        let trimmed = minutesText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let minutes = Int(trimmed), minutes > 0 else {
            return nil
        }
        return minutes
    }

    private func context() throws -> SQLContext {
        // 共有接続(6.3)。モデルごとに開くと database is locked を踏む
        return try AppDatabase.shared()
    }
}
