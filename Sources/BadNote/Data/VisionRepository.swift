import Foundation
import SkipSQL

public enum VisionRepositoryError: Error {
    /// 列の値が想定した型・値でない(スキーマと Swift 側のズレ)
    case unreadableColumn(name: String)
}

/// めざす姿(`vision`)の永続化。テーブルは 1 レコードのみ(§6)。
///
/// 行の有無は呼び出し側に見せない。未保存なら空の `Vision` を返し、保存は常に
/// 同じ id の行を置き換える。「初回だけ INSERT、以降は UPDATE」を呼び出し側に
/// 書かせないための境界。
///
/// `now` はテストからクロックを差し替えるための注入点。
public final class VisionRepository {
    private let db: SQLContext
    private let now: () -> Date
    private let timestamps = SQLTimestamp()

    /// 1 レコードのみなので id は固定。`vision.id` は AUTOINCREMENT ではない(§6)。
    private static let rowID: Int64 = 1

    public init(db: SQLContext, now: @escaping () -> Date = { Date() }) {
        self.db = db
        self.now = now
    }

    /// めざす姿を取得する。**未保存でも nil は返さない。**
    ///
    /// 一度も保存していなければ空の `Vision`(`updatedAt` は nil)を返す。
    /// 読むだけで行は作らない。
    public func fetch() throws -> Vision {
        let rows = try db.selectAll(sql: "SELECT body, image_path, updated_at FROM vision WHERE id = ?",
                                    parameters: [.long(VisionRepository.rowID)])
        guard let row = rows.first else {
            return Vision()
        }
        return try decode(row)
    }

    /// めざす姿を保存して、保存された内容を返す。
    ///
    /// 何度呼んでも行は 1 つ。`updated_at` は引数の値ではなくクロックの現在時刻で上書きする。
    ///
    /// UPSERT(`ON CONFLICT ... DO UPDATE`)は SQLite 3.24 以降で、
    /// Android API 28 は 3.22 のため使えない。id 固定の `INSERT OR REPLACE` にする。
    @discardableResult
    public func save(_ vision: Vision) throws -> Vision {
        try db.exec(sql: "INSERT OR REPLACE INTO vision (id, body, image_path, updated_at) VALUES (?, ?, ?, ?)",
                    parameters: [
                        SQLValue.long(VisionRepository.rowID),
                        SQLValue.text(vision.body),
                        textValue(vision.imagePath),
                        SQLValue.text(timestamps.text(from: now())),
                    ])
        return try fetch()
    }

    // MARK: - 変換

    private func decode(_ row: [SQLValue]) throws -> Vision {
        guard let body = row[0].textValue else {
            throw VisionRepositoryError.unreadableColumn(name: "body")
        }
        guard let updatedAtText = row[2].textValue,
              let updatedAt = timestamps.date(from: updatedAtText) else {
            throw VisionRepositoryError.unreadableColumn(name: "updated_at")
        }

        return Vision(body: body,
                      imagePath: row[1].textValue,
                      updatedAt: updatedAt)
    }

    private func textValue(_ value: String?) -> SQLValue {
        guard let value = value else {
            return .null
        }
        return .text(value)
    }
}
