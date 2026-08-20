import Foundation
import SkipSQL

/// スキーマの定義とマイグレーション。
///
/// SkipSQL の `userVersion` ベースのマイグレーションを使う(`docs/spec.md` §6)。
///
/// **テーブルを追加するときは `migrations` の末尾に 1 要素足すこと。**
/// 既存の要素を書き換えると、適用済みの DB にその変更が届かない。
public struct AppDatabase {
    private init() {
    }

    /// 未適用のマイグレーションを順に適用する。適用済みの場合は何もしない。
    public static func migrate(_ db: SQLContext) throws {
        try db.migrate(migrations: [
            { context in
                try context.exec(sql: AppDatabase.createIssueTable)
            },
        ])
    }

    /// 課題(§6)。日付・時刻は ISO 8601 の TEXT。json 関数は使わない。
    static let createIssueTable = """
        CREATE TABLE issue (
          id              INTEGER PRIMARY KEY AUTOINCREMENT,
          coach_words     TEXT NOT NULL,
          done_form       TEXT,
          coach_name      TEXT,
          discipline      TEXT NOT NULL DEFAULT 'both',
          mastery_level   INTEGER NOT NULL DEFAULT 1,
          tier            TEXT NOT NULL DEFAULT 'someday',
          sort_order      INTEGER NOT NULL DEFAULT 0,
          impact          INTEGER,
          cost            INTEGER,
          status          TEXT NOT NULL DEFAULT 'inbox',
          resurface_count INTEGER NOT NULL DEFAULT 0,
          last_focused_at TEXT,
          created_at      TEXT NOT NULL,
          updated_at      TEXT NOT NULL,
          archived_at     TEXT
        )
        """
}
