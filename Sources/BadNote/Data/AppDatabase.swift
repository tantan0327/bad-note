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

    /// 接続を使える状態にする。**接続を開いたら必ず呼ぶこと。**
    ///
    /// 外部キー制約は SQLite の既定で OFF、しかも**接続ごと**の設定なので、
    /// ここで ON にしないと `ON DELETE CASCADE` も参照チェックも黙って効かない。
    /// トランザクションの中では変更できないため、マイグレーションより先に実行する。
    public static func prepare(_ db: SQLContext) throws {
        try db.exec(sql: "PRAGMA foreign_keys = ON")
        try AppDatabase.migrate(db)
    }

    /// 未適用のマイグレーションを順に適用する。適用済みの場合は何もしない。
    private static func migrate(_ db: SQLContext) throws {
        try db.migrate(migrations: [
            { context in
                try context.exec(sql: AppDatabase.createIssueTable)
            },
            { context in
                try context.exec(sql: AppDatabase.createPracticeTable)
                try context.exec(sql: AppDatabase.createFocusRecordTable)
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

    /// 練習ログ(§6)
    static let createPracticeTable = """
        CREATE TABLE practice (
          id            INTEGER PRIMARY KEY AUTOINCREMENT,
          practice_date TEXT NOT NULL,
          minutes       INTEGER NOT NULL DEFAULT 0,
          kind          TEXT,
          created_at    TEXT NOT NULL
        )
        """

    /// 手応え(§6)。練習ログ × 重点課題。
    /// `UNIQUE (practice_id, issue_id)` で 1 練習 1 課題につき 1 行。
    static let createFocusRecordTable = """
        CREATE TABLE focus_record (
          id          INTEGER PRIMARY KEY AUTOINCREMENT,
          practice_id INTEGER NOT NULL REFERENCES practice(id) ON DELETE CASCADE,
          issue_id    INTEGER NOT NULL REFERENCES issue(id) ON DELETE CASCADE,
          result      TEXT,
          UNIQUE (practice_id, issue_id)
        )
        """
}
