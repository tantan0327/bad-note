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

    /// アプリ全体で共有する 1 本の接続(tasks.md 6.3)。**画面のモデルは必ずこれを使う。**
    ///
    /// モデルごとに接続を開くと、書き込み中に別の接続が `database is locked` を踏む
    /// (実際に通知設定の保存で踏んだ。インメモリのテストでは再現しない)。
    /// UI のモデルはメインスレッドからしか触らない前提。テストは従来どおり
    /// インメモリの接続を個別に作る。
    public static func shared() throws -> SQLContext {
        if let context = sharedContext {
            return context
        }
        let opened = try open()
        sharedContext = opened
        return opened
    }

    // UI のモデル(メインスレッド)からしか触らない前提なので unsafe を許す
    nonisolated(unsafe) private static var sharedContext: SQLContext? = nil

    /// アプリのデータベースを開く。`prepare(_:)` 済みの接続を返す。
    ///
    /// 保存先は Application Support。iOS も Android も同じコードで解決できる。
    /// 画面からは直接呼ばず `shared()` を使うこと(6.3)。
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
        try db.migrate(migrations: AppDatabase.migrations)
    }

    /// スキーマの変遷。**末尾に 1 要素足す。既存の要素は書き換えない。**
    ///
    /// 配列として外に出してあるのは、テストが**前半だけを適用して古い版の DB を作り、
    /// そこから今の版に上げられるか**を確かめるため(`MigrationTests`)。
    /// 適用済みのバージョン数は `userVersion` に入る。
    ///
    /// 計算プロパティなのは、クロージャの配列を `static let` で持つと
    /// 並行性の検査に引っかかるため(呼ぶのは起動時の 1 回だけなので作り直しでよい)。
    static var migrations: [(SQLContext) throws -> Void] {
        return [
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
            { context in
                try context.exec(sql: AppDatabase.createTrainingMenuTable)
                try context.exec(sql: AppDatabase.createTrainingLogTable)
            },
            { context in
                // §7.5 大会のねらい。既存の大会は NULL(未記入)
                try context.exec(sql: "ALTER TABLE competition ADD COLUMN aim TEXT")
            },
            { context in
                try context.exec(sql: AppDatabase.createPracticePlanTable)
                // §8 練習前の通知は曜日ではなく練習予定日で出すようになった。
                // 役目を終えたキーを残すと、`ExportRepository` が書き出し続け、
                // 「設定は残っているのに曜日では鳴らない」状態になる。
                // `appMetaDefaults` にこのキーは無いので復活しない
                try context.exec(sql: "DELETE FROM app_meta WHERE key = 'practice_reminder_weekdays'")
            },
            { context in
                // §3.2 「1 つ戻す」提案を断った記録。既存の課題は NULL(まだ断っていない)。
                // `level_up_declined_level` と列を分けるのは、**上げるのを断ったことが
                // 戻す提案まで黙らせるのは誤り**だから
                try context.exec(sql: "ALTER TABLE issue ADD COLUMN step_down_declined_level INTEGER")
            },
        ]
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

    /// 家トレのメニュー(§10.4)。繰り返しやる決めごと。削除ではなくアーカイブ。
    static let createTrainingMenuTable = """
        CREATE TABLE training_menu (
          id          INTEGER PRIMARY KEY AUTOINCREMENT,
          name        TEXT NOT NULL,
          minutes     INTEGER,
          sort_order  INTEGER NOT NULL DEFAULT 0,
          is_archived INTEGER NOT NULL DEFAULT 0,
          created_at  TEXT NOT NULL
        )
        """

    /// 家トレの実施記録(§10.4)。1 日 × 1 メニューで 1 行。
    /// `training_date` はローカルの暦日の TEXT(`2026-08-22`)。タイムスタンプではない。
    static let createTrainingLogTable = """
        CREATE TABLE training_log (
          id            INTEGER PRIMARY KEY AUTOINCREMENT,
          menu_id       INTEGER NOT NULL REFERENCES training_menu(id) ON DELETE CASCADE,
          training_date TEXT NOT NULL,
          minutes       INTEGER,
          done_at       TEXT,
          UNIQUE (menu_id, training_date)
        )
        """

    /// 練習予定日(§5.2)。**大会までの残り練習回数はここを数える**(推定しない)。
    ///
    /// `plan_date` はローカルの暦日の TEXT(`2026-09-07`)。タイムスタンプではない ——
    /// 「9/7 に練習する」の単位は家トレの `training_date` と同じ暦日で、
    /// 辞書順 = 日付順なので期間の絞り込みがそのまま効く。
    ///
    /// **主キーが `plan_date`** なので、同じ日は 1 行しか持てない。
    /// `INSERT OR IGNORE` だけで重複が構造的に起きず、まとめて追加を何度押しても増えない。
    /// 大会には紐付けない —— 練習予定は生活の予定で、種目ごとに二重に持つものではない。
    static let createPracticePlanTable = """
        CREATE TABLE practice_plan (
          plan_date  TEXT PRIMARY KEY,
          created_at TEXT NOT NULL
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
