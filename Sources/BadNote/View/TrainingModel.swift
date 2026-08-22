import Foundation
import Observation
import SkipSQL

/// 家トレ画面の状態(§10.2)。
///
/// 選んだ日のメニューとチェック状態を持つ。**未達の数は持たない**(§5.3)。
/// 出す数字はチェックが付いた分の合計だけ。
@Observable public final class TrainingModel {
    /// 表示している日。既定は今日。昨日以前にさかのぼれる(§10.2)。
    public var date = Date()

    public private(set) var menus: [TrainingMenu] = []
    /// 表示中の日の実施記録。メニュー id 引き。
    public private(set) var logs: [Int64: TrainingLog] = [:]
    public var errorText: String? = nil

    private var database: SQLContext? = nil
    private let days = DayStamp()

    public init() {
    }

    public func load() {
        do {
            let db = try context()
            let repo = TrainingRepository(db: db)
            menus = try repo.fetchMenus()
            var byMenu: [Int64: TrainingLog] = [:]
            for log in try repo.fetchLogs(on: date) {
                byMenu[log.menuId] = log
            }
            logs = byMenu
            errorText = nil
        } catch {
            errorText = "家トレの読み込みに失敗しました: \(error)"
        }
    }

    public func isDone(_ menu: TrainingMenu) -> Bool {
        return logs[menu.id] != nil
    }

    /// チェックの付け外し(§10.2 押し間違いは必ず起きるので外せる)。
    public func toggle(_ menu: TrainingMenu) {
        do {
            let db = try context()
            let repo = TrainingRepository(db: db)
            if isDone(menu) {
                try repo.uncheck(menuId: menu.id, on: date)
                logs[menu.id] = nil
            } else {
                logs[menu.id] = try repo.check(menuId: menu.id, on: date)
            }
            errorText = nil
        } catch {
            errorText = "記録に失敗しました: \(error)"
        }
    }

    /// チェックが付いた分の合計(§10.2)。分数の無いメニューは 0 分。
    public var doneMinutes: Int {
        var total = 0
        for log in logs.values {
            total += log.minutes ?? 0
        }
        return total
    }

    public var isToday: Bool {
        return days.text(from: date) == days.text(from: Date())
    }

    public func backToToday() {
        date = Date()
        load()
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
