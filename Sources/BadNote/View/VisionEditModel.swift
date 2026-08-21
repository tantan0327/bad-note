import Foundation
import Observation
import SkipSQL

/// めざす姿の編集画面の状態(§7.1)。
///
/// レコードは 1 件だけ。未保存でも `VisionRepository.fetch()` が空の `Vision` を返すので、
/// 「初回かどうか」をここで分岐する必要はない。
@Observable public final class VisionEditModel {

    public var body = ""
    public var errorText: String? = nil
    public var isSaved = false

    private var database: SQLContext? = nil

    public init() {
    }

    public func load() {
        do {
            body = try VisionRepository(db: try context()).fetch().body
            errorText = nil
        } catch {
            errorText = "読み込みに失敗しました: \(error)"
        }
    }

    /// 空のままでも保存できる。書けないときに詰まらせない。
    public func save() {
        do {
            let repo = VisionRepository(db: try context())
            var vision = try repo.fetch()
            vision.body = body
            _ = try repo.save(vision)
            errorText = nil
            isSaved = true
        } catch {
            errorText = "保存に失敗しました: \(error)"
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
