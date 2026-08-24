import Foundation
import SkipSQL

public enum TrainingRepositoryError: Error {
    /// 指定した id のメニューが無い
    case notFound(id: Int64)
    /// 列の値が想定した型・値でない(スキーマと Swift 側のズレ)
    case unreadableColumn(name: String)
}

/// 家トレ(§10)。メニュー(`training_menu`)と実施記録(`training_log`)の永続化。
///
/// - 実施記録は「暦日 × メニュー」で 1 行。付け直しても増えない
/// - チェック時にメニューの分数を写して固定する(§10.3)。後から目安を直しても
///   過去の積み上げは変わらない
/// - メニューは削除せずアーカイブする(§10.2)。過去の実施記録を守る
///
/// `now` はテストからクロックを差し替えるための注入点。
public final class TrainingRepository {
    private let db: SQLContext
    private let now: () -> Date
    private let timestamps = SQLTimestamp()
    private let days = DayStamp()

    public init(db: SQLContext, now: @escaping () -> Date = { Date() }) {
        self.db = db
        self.now = now
    }

    /// SELECT の列。並びは `decodeMenu(_:)` の添字と対応している。
    private static let menuColumns = "id, name, minutes, sort_order, is_archived, created_at"
    /// 並びは `decodeLog(_:)` の添字と対応している。
    private static let logColumns = "id, menu_id, training_date, minutes, done_at"

    // MARK: - メニュー

    /// メニューを末尾に追加する。目安の分数は任意(§10.1)。
    @discardableResult
    public func createMenu(name: String, minutes: Int? = nil) throws -> TrainingMenu {
        let rows = try db.selectAll(sql: "SELECT COALESCE(MAX(sort_order), -1) + 1 FROM training_menu")
        let order = rows.first?.first?.longValue ?? Int64(0)
        try db.exec(sql: "INSERT INTO training_menu (name, minutes, sort_order, created_at) VALUES (?, ?, ?, ?)",
                    parameters: [
                        SQLValue.text(name),
                        longValue(minutes),
                        SQLValue.long(order),
                        SQLValue.text(timestamps.text(from: now())),
                    ])
        return try requireMenu(id: db.lastInsertRowID)
    }

    public func fetchMenu(id: Int64) throws -> TrainingMenu? {
        let rows = try db.selectAll(sql: "SELECT \(TrainingRepository.menuColumns) FROM training_menu WHERE id = ?",
                                    parameters: [.long(id)])
        guard let row = rows.first else {
            return nil
        }
        return try decodeMenu(row)
    }

    /// 並びは sort_order。既定ではアーカイブ済みを含めない(§10.2)。
    public func fetchMenus(includeArchived: Bool = false) throws -> [TrainingMenu] {
        let condition = includeArchived ? "" : "WHERE is_archived = 0"
        let rows = try db.selectAll(sql: "SELECT \(TrainingRepository.menuColumns) FROM training_menu \(condition) ORDER BY sort_order, id")
        var menus: [TrainingMenu] = []
        for row in rows {
            menus.append(try decodeMenu(row))
        }
        return menus
    }

    /// 名前・目安の分数・並び・アーカイブ状態を更新する。`created_at` は更新しない。
    ///
    /// 過去の実施記録には触れない(§10.3 分数は写して固定してある)。
    @discardableResult
    public func updateMenu(_ menu: TrainingMenu) throws -> TrainingMenu {
        try db.exec(sql: "UPDATE training_menu SET name = ?, minutes = ?, sort_order = ?, is_archived = ? WHERE id = ?",
                    parameters: [
                        SQLValue.text(menu.name),
                        longValue(menu.minutes),
                        SQLValue.long(Int64(menu.sortOrder)),
                        SQLValue.long(menu.isArchived ? Int64(1) : Int64(0)),
                        SQLValue.long(menu.id),
                    ])
        return try requireMenu(id: menu.id)
    }

    /// メニューをアーカイブする(§10.2)。一覧から消えるが、実施記録は残る。
    public func archiveMenu(id: Int64) throws {
        try db.exec(sql: "UPDATE training_menu SET is_archived = 1 WHERE id = ?", parameters: [.long(id)])
    }

    /// 渡した順に sort_order を 0 から振り直す。
    public func reorderMenus(ids: [Int64]) throws {
        try db.transaction {
            for (index, id) in ids.enumerated() {
                try db.exec(sql: "UPDATE training_menu SET sort_order = ? WHERE id = ?",
                            parameters: [.long(Int64(index)), .long(id)])
            }
        }
    }

    // MARK: - 実施記録

    /// その日のチェックを付ける。メニューの分数を写して固定する(§10.3)。
    ///
    /// 同じ日に 2 回呼んでも 1 行のまま(`UNIQUE (menu_id, training_date)` を
    /// `INSERT OR REPLACE` で上書きする。行 id は変わるが、id を参照する所は無い)。
    @discardableResult
    public func check(menuId: Int64, on date: Date) throws -> TrainingLog {
        let menu = try requireMenu(id: menuId)
        let day = days.text(from: date)
        try db.exec(sql: "INSERT OR REPLACE INTO training_log (menu_id, training_date, minutes, done_at) VALUES (?, ?, ?, ?)",
                    parameters: [
                        SQLValue.long(menuId),
                        SQLValue.text(day),
                        longValue(menu.minutes),
                        SQLValue.text(timestamps.text(from: now())),
                    ])
        guard let log = try fetchLog(menuId: menuId, day: day) else {
            throw TrainingRepositoryError.notFound(id: menuId)
        }
        return log
    }

    /// その日のチェックを外す(§10.2 押し間違いは必ず起きる)。行ごと消す。
    public func uncheck(menuId: Int64, on date: Date) throws {
        try db.exec(sql: "DELETE FROM training_log WHERE menu_id = ? AND training_date = ?",
                    parameters: [.long(menuId), .text(days.text(from: date))])
    }

    /// その日の分数を後から直す(日によって時間が変わる。§10.3)。
    ///
    /// 直せるのはチェック済みの日だけ(行が無ければ投げる。黙って成功にしない)。
    /// `done_at` は変えない。メニューの目安には触らない。
    @discardableResult
    public func setMinutes(menuId: Int64, on date: Date, minutes: Int?) throws -> TrainingLog {
        let day = days.text(from: date)
        guard try fetchLog(menuId: menuId, day: day) != nil else {
            throw TrainingRepositoryError.notFound(id: menuId)
        }
        try db.exec(sql: "UPDATE training_log SET minutes = ? WHERE menu_id = ? AND training_date = ?",
                    parameters: [
                        longValue(minutes),
                        SQLValue.long(menuId),
                        SQLValue.text(day),
                    ])
        guard let log = try fetchLog(menuId: menuId, day: day) else {
            throw TrainingRepositoryError.notFound(id: menuId)
        }
        return log
    }

    /// その日の実施記録。
    public func fetchLogs(on date: Date) throws -> [TrainingLog] {
        let rows = try db.selectAll(sql: "SELECT \(TrainingRepository.logColumns) FROM training_log WHERE training_date = ?",
                                    parameters: [.text(days.text(from: date))])
        var logs: [TrainingLog] = []
        for row in rows {
            logs.append(try decodeLog(row))
        }
        return logs
    }

    /// 期間内の家トレ分数の合計。`from` の暦日以上 `to` の暦日**未満**(日単位の半開区間)。
    ///
    /// 分数の無い実施記録は 0 分として入る(§10.3)。
    /// 呼ぶのは `StatsRepository` だけにすること(§10.3 集計の入り口は 1 つ)。
    public func totalMinutes(from: Date, to: Date) throws -> Int {
        let rows = try db.selectAll(sql: """
            SELECT SUM(COALESCE(minutes, 0))
            FROM training_log
            WHERE training_date >= ? AND training_date < ? AND done_at IS NOT NULL
            """,
            parameters: [
                .text(days.text(from: from)),
                .text(days.text(from: to)),
            ])
        // 1 件も無いとき SUM は NULL
        guard let total = rows.first?.first?.longValue else {
            return 0
        }
        return Int(total)
    }

    /// 全期間の家トレ分数の合計。`StatsRepository` だけから呼ぶ(§10.3)。
    public func totalMinutes() throws -> Int {
        let rows = try db.selectAll(sql: "SELECT SUM(COALESCE(minutes, 0)) FROM training_log WHERE done_at IS NOT NULL")
        guard let total = rows.first?.first?.longValue else {
            return 0
        }
        return Int(total)
    }

    // MARK: - 変換

    private func fetchLog(menuId: Int64, day: String) throws -> TrainingLog? {
        let rows = try db.selectAll(sql: "SELECT \(TrainingRepository.logColumns) FROM training_log WHERE menu_id = ? AND training_date = ?",
                                    parameters: [.long(menuId), .text(day)])
        guard let row = rows.first else {
            return nil
        }
        return try decodeLog(row)
    }

    private func requireMenu(id: Int64) throws -> TrainingMenu {
        guard let menu = try fetchMenu(id: id) else {
            throw TrainingRepositoryError.notFound(id: id)
        }
        return menu
    }

    private func decodeMenu(_ row: [SQLValue]) throws -> TrainingMenu {
        guard let id = row[0].longValue else {
            throw TrainingRepositoryError.unreadableColumn(name: "id")
        }
        guard let name = row[1].textValue else {
            throw TrainingRepositoryError.unreadableColumn(name: "name")
        }
        guard let sortOrder = row[3].longValue else {
            throw TrainingRepositoryError.unreadableColumn(name: "sort_order")
        }
        guard let archived = row[4].longValue else {
            throw TrainingRepositoryError.unreadableColumn(name: "is_archived")
        }
        guard let createdAtText = row[5].textValue,
              let createdAt = timestamps.date(from: createdAtText) else {
            throw TrainingRepositoryError.unreadableColumn(name: "created_at")
        }

        return TrainingMenu(id: id,
                            name: name,
                            minutes: intValue(row[2]),
                            sortOrder: Int(sortOrder),
                            isArchived: archived != Int64(0),
                            createdAt: createdAt)
    }

    private func decodeLog(_ row: [SQLValue]) throws -> TrainingLog {
        guard let id = row[0].longValue else {
            throw TrainingRepositoryError.unreadableColumn(name: "id")
        }
        guard let menuId = row[1].longValue else {
            throw TrainingRepositoryError.unreadableColumn(name: "menu_id")
        }
        guard let trainingDate = row[2].textValue else {
            throw TrainingRepositoryError.unreadableColumn(name: "training_date")
        }

        var doneAt: Date? = nil
        if let doneAtText = row[4].textValue {
            doneAt = timestamps.date(from: doneAtText)
        }

        return TrainingLog(id: id,
                           menuId: menuId,
                           trainingDate: trainingDate,
                           minutes: intValue(row[3]),
                           doneAt: doneAt)
    }

    private func intValue(_ value: SQLValue) -> Int? {
        guard let long = value.longValue else {
            return nil
        }
        return Int(long)
    }

    private func longValue(_ value: Int?) -> SQLValue {
        guard let value = value else {
            return .null
        }
        return .long(Int64(value))
    }
}
