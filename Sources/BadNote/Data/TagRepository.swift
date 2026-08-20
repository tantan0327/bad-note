import Foundation
import SkipSQL

public enum TagRepositoryError: Error {
    /// 空白だけのタグ名は作れない
    case blankName
    /// 列の値が想定した型・値でない(スキーマと Swift 側のズレ)
    case unreadableColumn(name: String)
    /// 直後に読み直したタグが見つからない(通常は起きない)
    case notFound(name: String)
}

/// タグ(`tag`)と課題への紐付け(`issue_tag`)の永続化。
///
/// 配列を 1 カラムに詰めず中間テーブルにする(§6)。タグ名の一意性は
/// `tag.name` の UNIQUE 制約で担保し、`create(name:)` は同名なら既存を返す。
public final class TagRepository {
    private let db: SQLContext

    public init(db: SQLContext) {
        self.db = db
    }

    private static let columns = "id, name"

    // MARK: - タグ

    /// タグを作る。**同名のタグが既にあればそれを返す**(新しい行は作らない)。
    ///
    /// 前後の空白は落とす。空白違いで見た目が同じタグが 2 つできるのを防ぐため。
    /// 大文字小文字は区別する(SQLite の既定の照合順)。
    @discardableResult
    public func create(name: String) throws -> Tag {
        let trimmed = name.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if trimmed.isEmpty {
            throw TagRepositoryError.blankName
        }
        // 読んでから書くのではなく UNIQUE 制約に任せる
        try db.exec(sql: "INSERT OR IGNORE INTO tag (name) VALUES (?)", parameters: [.text(trimmed)])
        guard let tag = try fetch(name: trimmed) else {
            throw TagRepositoryError.notFound(name: trimmed)
        }
        return tag
    }

    public func fetch(name: String) throws -> Tag? {
        let rows = try db.selectAll(sql: "SELECT \(TagRepository.columns) FROM tag WHERE name = ?",
                                    parameters: [.text(name)])
        guard let row = rows.first else {
            return nil
        }
        return try decode(row)
    }

    /// 名前順。§7.4 の絞り込み行に並べる用途。
    public func fetchAll() throws -> [Tag] {
        let rows = try db.selectAll(sql: "SELECT \(TagRepository.columns) FROM tag ORDER BY name")
        return try decodeAll(rows)
    }

    /// タグを削除する。課題への紐付けは `ON DELETE CASCADE` で一緒に消える。
    /// 課題そのものは消えない。
    public func delete(id: Int64) throws {
        try db.exec(sql: "DELETE FROM tag WHERE id = ?", parameters: [.long(id)])
    }

    // MARK: - 課題への付け外し

    /// 課題にタグを付ける。既に付いていれば何もしない。
    ///
    /// 存在しない課題・タグを指すと外部キー制約で失敗する
    /// (`OR IGNORE` は外部キー違反には効かない)。
    public func attach(tagId: Int64, to issueId: Int64) throws {
        try db.exec(sql: "INSERT OR IGNORE INTO issue_tag (issue_id, tag_id) VALUES (?, ?)",
                    parameters: [.long(issueId), .long(tagId)])
    }

    /// 課題からタグを外す。付いていなければ何もしない。
    public func detach(tagId: Int64, from issueId: Int64) throws {
        try db.exec(sql: "DELETE FROM issue_tag WHERE issue_id = ? AND tag_id = ?",
                    parameters: [.long(issueId), .long(tagId)])
    }

    /// 課題のタグを `tags` の集合に合わせる。足りないものを付け、余分なものを外す。
    ///
    /// 画面の状態をそのまま渡せる形。差分の計算を呼び出し側に書かせないための入口。
    public func setTags(_ tags: [Tag], for issueId: Int64) throws {
        let stored = try fetchTags(issueId: issueId)
        for existing in stored {
            var keep = false
            for tag in tags {
                if tag.id == existing.id {
                    keep = true
                }
            }
            if !keep {
                try detach(tagId: existing.id, from: issueId)
            }
        }
        for tag in tags {
            try attach(tagId: tag.id, to: issueId)
        }
    }

    /// 課題に付いているタグ。名前順。
    public func fetchTags(issueId: Int64) throws -> [Tag] {
        let rows = try db.selectAll(sql: """
            SELECT t.id, t.name
            FROM tag t
            JOIN issue_tag it ON it.tag_id = t.id
            WHERE it.issue_id = ?
            ORDER BY t.name
            """,
            parameters: [.long(issueId)])
        return try decodeAll(rows)
    }

    // MARK: - 変換

    private func decodeAll(_ rows: [[SQLValue]]) throws -> [Tag] {
        var tags: [Tag] = []
        for row in rows {
            tags.append(try decode(row))
        }
        return tags
    }

    private func decode(_ row: [SQLValue]) throws -> Tag {
        guard let id = row[0].longValue else {
            throw TagRepositoryError.unreadableColumn(name: "id")
        }
        guard let name = row[1].textValue else {
            throw TagRepositoryError.unreadableColumn(name: "name")
        }
        return Tag(id: id, name: name)
    }
}
