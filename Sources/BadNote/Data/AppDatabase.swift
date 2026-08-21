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

    /// アプリのデータベースを開く。`prepare(_:)` 済みの接続を返す。
    ///
    /// 保存先は Application Support。iOS も Android も同じコードで解決できる。
    public static func open() throws -> SQLContext {
        let directory = URL.applicationSupportDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let path = directory.appendingPathComponent("badnote.sqlite").path
        let db = try SQLContext(path: path, configuration: .platform)
        try AppDatabase.prepare(db)
        return db
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
            { context in
                try context.exec(sql: AppDatabase.createCompetitionTable)
                try context.exec(sql: AppDatabase.createCompetitionEntryTable)
            },
            { context in
                try context.exec(sql: AppDatabase.createVisionTable)
            },
            { context in
                try context.exec(sql: AppDatabase.createTagTable)
                try context.exec(sql: AppDatabase.createIssueTagTable)
            },
            { context in
                // §3.2「1 度だけ提案する」の記録。既存の課題は NULL(まだ断っていない)
                try context.exec(sql: "ALTER TABLE issue ADD COLUMN level_up_declined_level INTEGER")
            },
            { context in
                try context.exec(sql: AppDatabase.createLevelChangeTable)
            },
            { context in
                try context.exec(sql: AppDatabase.createFocusSpanTable)
                try context.exec(sql: AppDatabase.createStaleFlagTable)
                try context.exec(sql: AppDatabase.createAppMetaTable)
                for statement in AppDatabase.appMetaDefaults {
                    try context.exec(sql: statement)
                }
            },
            { context in
                try context.exec(sql: AppDatabase.createIssueCompetitionTable)
                try context.exec(sql: AppDatabase.createCompetitionReviewTable)
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

    /// 大会(§6)
    static let createCompetitionTable = """
        CREATE TABLE competition (
          id          INTEGER PRIMARY KEY AUTOINCREMENT,
          name        TEXT NOT NULL,
          event_date  TEXT NOT NULL,
          venue       TEXT,
          created_at  TEXT NOT NULL
        )
        """

    /// 大会のエントリー種目(§6)。1 大会が複数種目を持てる。
    /// `is_target = 1` を discipline ごとに最大 1 件に保つのはアプリ側の責務
    /// (`CompetitionRepository`)。SQL の制約では表現できない。
    static let createCompetitionEntryTable = """
        CREATE TABLE competition_entry (
          id             INTEGER PRIMARY KEY AUTOINCREMENT,
          competition_id INTEGER NOT NULL REFERENCES competition(id) ON DELETE CASCADE,
          discipline     TEXT NOT NULL,
          is_target      INTEGER NOT NULL DEFAULT 0,
          UNIQUE (competition_id, discipline)
        )
        """

    /// めざす姿(§6)。1 レコードのみ。id は AUTOINCREMENT にしない。
    static let createVisionTable = """
        CREATE TABLE vision (
          id          INTEGER PRIMARY KEY,
          body        TEXT NOT NULL DEFAULT '',
          image_path  TEXT,
          updated_at  TEXT NOT NULL
        )
        """

    /// タグ(§6)。名前は UNIQUE。
    static let createTagTable = """
        CREATE TABLE tag (
          id    INTEGER PRIMARY KEY AUTOINCREMENT,
          name  TEXT NOT NULL UNIQUE
        )
        """

    /// 課題とタグの紐付け(§6)。配列を 1 カラムに詰めず中間テーブルにする。
    static let createIssueTagTable = """
        CREATE TABLE issue_tag (
          issue_id INTEGER NOT NULL REFERENCES issue(id) ON DELETE CASCADE,
          tag_id   INTEGER NOT NULL REFERENCES tag(id) ON DELETE CASCADE,
          PRIMARY KEY (issue_id, tag_id)
        )
        """

    /// 習熟度の変更履歴(§6)
    static let createLevelChangeTable = """
        CREATE TABLE level_change (
          id         INTEGER PRIMARY KEY AUTOINCREMENT,
          issue_id   INTEGER NOT NULL REFERENCES issue(id) ON DELETE CASCADE,
          from_level INTEGER NOT NULL,
          to_level   INTEGER NOT NULL,
          created_at TEXT NOT NULL
        )
        """

    /// focus 在籍履歴(§6)。stale 条件と §7.3「重点にした回数」を賄う。
    static let createFocusSpanTable = """
        CREATE TABLE focus_span (
          id         INTEGER PRIMARY KEY AUTOINCREMENT,
          issue_id   INTEGER NOT NULL REFERENCES issue(id) ON DELETE CASCADE,
          entered_at TEXT NOT NULL,
          left_at    TEXT
        )
        """

    /// stale の週次スナップショット(§6)。3 択の処理で 1 行ずつ消す。
    static let createStaleFlagTable = """
        CREATE TABLE stale_flag (
          issue_id     INTEGER PRIMARY KEY REFERENCES issue(id) ON DELETE CASCADE,
          reason       TEXT NOT NULL,
          evaluated_at TEXT NOT NULL
        )
        """

    /// 設定・メタ(§6)
    static let createAppMetaTable = """
        CREATE TABLE app_meta (
          key   TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
        """

    /// §4.2 の初期値。
    static let appMetaDefaults = [
        "INSERT OR IGNORE INTO app_meta (key, value) VALUES ('stale_days', '21')",
        "INSERT OR IGNORE INTO app_meta (key, value) VALUES ('stale_practice_count', '6')",
        "INSERT OR IGNORE INTO app_meta (key, value) VALUES ('reshuffle_weekday', '0')",
        "INSERT OR IGNORE INTO app_meta (key, value) VALUES ('stale_last_evaluated_at', '')",
    ]

    /// 課題と大会の紐付け(§6)
    static let createIssueCompetitionTable = """
        CREATE TABLE issue_competition (
          issue_id       INTEGER NOT NULL REFERENCES issue(id) ON DELETE CASCADE,
          competition_id INTEGER NOT NULL REFERENCES competition(id) ON DELETE CASCADE,
          PRIMARY KEY (issue_id, competition_id)
        )
        """

    /// 大会後の振り返り(§6)。種目ごとに 1 件。
    static let createCompetitionReviewTable = """
        CREATE TABLE competition_review (
          id                INTEGER PRIMARY KEY AUTOINCREMENT,
          competition_id    INTEGER NOT NULL REFERENCES competition(id) ON DELETE CASCADE,
          discipline        TEXT NOT NULL,
          result            TEXT,
          went_well         TEXT,
          next_action       TEXT,
          needed_resources  TEXT,
          created_at        TEXT NOT NULL,
          UNIQUE (competition_id, discipline)
        )
        """
}
