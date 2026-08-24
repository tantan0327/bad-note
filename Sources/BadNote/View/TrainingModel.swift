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
    /// チェック操作の通し回数。触覚フィードバックのトリガー(3.1)。
    /// 日付の切り替えや再読み込みでは増えない(眺めただけで振動させない)。
    public private(set) var toggleCount = 0
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
            toggleCount += 1
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

    /// その日の分を全部チェックできたか(3.1 の静かな強調)。メニューが無い日は false。
    public var isAllDone: Bool {
        if menus.isEmpty {
            return false
        }
        for menu in menus {
            if !isDone(menu) {
                return false
            }
        }
        return true
    }

    public var isToday: Bool {
        return days.text(from: date) == days.text(from: Date())
    }

    public var isYesterday: Bool {
        guard let yesterday = Calendar.current.date(byAdding: Calendar.Component.day, value: -1, to: Date()) else {
            return false
        }
        return days.text(from: date) == days.text(from: yesterday)
    }

    /// 画面の見出し(3.2)。今日と昨日は言葉で、それ以前は日付で。
    public var dayTitle: String {
        if isToday {
            return "今日"
        }
        if isYesterday {
            return "昨日"
        }
        return TrainingModel.dayText(date)
    }

    /// 見出しの添え字。見出しが「今日 / 昨日」のときは日付、日付のときはさかのぼりの注記。
    public var daySubtitle: String {
        if isToday || isYesterday {
            return TrainingModel.dayText(date)
        }
        return "さかのぼって付けています"
    }

    /// 「8月24日(月)」。UI は日本語のみなので ja_JP 固定(英語対応は 6.2 と一緒に)。
    static func dayText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日(E)"
        return formatter.string(from: date)
    }

    /// 付け忘れの大半は昨日の分(3.2)。1 タップでさかのぼる。
    public func selectYesterday() {
        date = Calendar.current.date(byAdding: Calendar.Component.day, value: -1, to: Date()) ?? Date()
        load()
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
