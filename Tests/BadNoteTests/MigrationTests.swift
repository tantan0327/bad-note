import XCTest
import Foundation
import SkipSQL
@testable import BadNote

/// スキーマの更新経路(§6)。
///
/// **他のテストはすべて空のインメモリ DB から始まる** ので、
/// 「0 から全部を一気に適用する」経路しか通っていなかった。
/// 実際の利用者の端末にあるのは**途中のバージョンで、しかもデータが入っている DB** で、
/// そこを通す経路は一度も試されていなかった。ここで埋める。
///
/// マイグレーションは**追記のみ**(`AppDatabase.migrations` のコメント)。
/// 既存の要素を書き換えると、適用済みの DB にその変更は届かない ——
/// 新規インストールだけが正しくなり、**更新した人だけが壊れる**。
///
/// **注意**: `SQLContext.migrate` は `userVersion..<migrations.count` で回る。
/// 新しい DB に短い配列を渡すと範囲が逆転する。**必ず新規の DB に前半 → 全部の順で当てる。**
final class MigrationTests: XCTestCase {

    private func makeEmptyDatabase() -> SQLContext {
        // prepare は呼ばない。バージョン 0 の DB がほしい
        return SQLContext(configuration: .platform)
    }

    /// 先頭から `count` 本だけ適用した DB = 昔のアプリが作った DB。
    private func makeDatabase(migratedUpTo count: Int) throws -> SQLContext {
        let db = makeEmptyDatabase()
        var prefix: [(SQLContext) throws -> Void] = []
        let all = AppDatabase.migrations
        for index in 0..<count {
            prefix.append(all[index])
        }
        try db.exec(sql: "PRAGMA foreign_keys = ON")
        try db.migrate(migrations: prefix)
        return db
    }

    private func latestVersion() -> Int {
        return AppDatabase.migrations.count
    }

    // MARK: - バージョン番号

    /// `prepare` を通すと本数どおりのバージョンになる。
    /// **マイグレーションを足したのに適用されない**状態を検出する。
    func testPrepareReachesTheLatestVersion() throws {
        let db = makeEmptyDatabase()
        defer { try? db.close() }

        try AppDatabase.prepare(db)

        XCTAssertEqual(Int64(latestVersion()), db.userVersion)
    }

    /// 途中まで適用した DB は、そのバージョンで止まっている(足場の確認)。
    func testPartiallyMigratedDatabaseStopsAtThatVersion() throws {
        let db = try makeDatabase(migratedUpTo: 5)
        defer { try? db.close() }

        XCTAssertEqual(Int64(5), db.userVersion)
    }

    // MARK: - どのバージョンからでも上がれる

    /// **すべての段階から最新まで上がれる。** 途中の 1 本が落ちると、
    /// そのバージョンで止まっていた人だけが更新できなくなる。
    func testEveryVersionCanUpgradeToLatest() throws {
        for startVersion in 0...latestVersion() {
            let db = try makeDatabase(migratedUpTo: startVersion)
            defer { try? db.close() }

            try AppDatabase.prepare(db)

            XCTAssertEqual(Int64(latestVersion()), db.userVersion,
                           "バージョン \(startVersion) から上げられない")
        }
    }

    // MARK: - 既存のマイグレーションを書き換えていないこと

    /// **今のスキーマ。マイグレーションのコードとは独立に、ここに直接書いて固定する。**
    ///
    /// 独立に持つことが肝心 —— スキーマをマイグレーション配列から組み立てて
    /// 突き合わせても、**書き換えれば両側が同時に変わるので何も検出できない**
    /// (最初そう書いて、実際に検出できなかった)。
    ///
    /// **この一覧を直してよいのは、マイグレーションを末尾に足したときだけ。**
    /// 既存の要素を書き換えてここを合わせにきたなら、それは規則違反 ——
    /// 新規インストールだけが正しくなり、**更新した人の DB には変更が届かない**。
    /// 開発中は消して入れ直すので新規側しか見ておらず、手では気づけない。
    private let pinnedSchema = [
        "app_meta: key,value",
        "competition: aim,created_at,event_date,id,name,venue",
        "competition_entry: competition_id,discipline,id,is_target",
        "competition_review: competition_id,created_at,discipline,id,needed_resources,next_action,result,went_well",
        "focus_record: id,issue_id,practice_id,result",
        "focus_span: entered_at,id,issue_id,left_at",
        "issue: archived_at,coach_name,coach_words,cost,created_at,discipline,done_form,id,impact,last_focused_at,level_up_declined_level,mastery_level,resurface_count,sort_order,status,tier,updated_at",
        "issue_competition: competition_id,issue_id",
        "issue_tag: issue_id,tag_id",
        "level_change: created_at,from_level,id,issue_id,to_level",
        "practice: created_at,id,kind,minutes,practice_date",
        "practice_plan: created_at,plan_date",
        "stale_flag: evaluated_at,issue_id,reason",
        "tag: id,name",
        "training_log: done_at,id,menu_id,minutes,training_date",
        "training_menu: created_at,id,is_archived,minutes,name,sort_order",
        "vision: body,id,image_path,updated_at",
    ]

    /// 新規インストールが固定した一覧どおりになる。
    func testFreshInstallMatchesThePinnedSchema() throws {
        let db = makeEmptyDatabase()
        defer { try? db.close() }

        try AppDatabase.prepare(db)

        assertMatchesPinnedSchema(columns(of: db), label: "新規インストール")
    }

    /// 更新してきた DB も同じ一覧になる。**どのバージョンから来ても同じ形に着く。**
    func testUpgradedDatabaseMatchesThePinnedSchema() throws {
        for startVersion in 0..<latestVersion() {
            let db = try makeDatabase(migratedUpTo: startVersion)
            defer { try? db.close() }

            try AppDatabase.prepare(db)

            assertMatchesPinnedSchema(columns(of: db), label: "バージョン \(startVersion) から更新")
        }
    }

    /// **テーブルごとに**突き合わせる。一覧を丸ごと 1 回で比べると、
    /// 失敗時に 16 行が 1 つの文字列になって**どこが違うのか読めない**。
    private func assertMatchesPinnedSchema(_ actual: [String], label: String) {
        XCTAssertEqual(pinnedSchema.count, actual.count, "\(label): テーブルの数が違う")
        var count = pinnedSchema.count
        if actual.count < count {
            count = actual.count
        }
        for index in 0..<count {
            XCTAssertEqual(pinnedSchema[index], actual[index], "\(label): スキーマが違う")
        }
    }

    /// テーブルごとの列名(名前順)。`sqlite_sequence` などの内部テーブルは外す。
    private func columns(of db: SQLContext) -> [String] {
        let tables = (try? db.selectAll(sql: """
            SELECT name FROM sqlite_master
            WHERE type = 'table' AND sql IS NOT NULL AND name NOT LIKE 'sqlite_%'
            ORDER BY name
            """)) ?? []
        var lines: [String] = []
        for table in tables {
            let name = table.first?.textValue ?? ""
            let info = (try? db.selectAll(sql: "PRAGMA table_info(\(name))")) ?? []
            var names: [String] = []
            for column in info {
                if column.count > 1 {
                    names.append(column[1].textValue ?? "")
                }
            }
            // sorted() の戻り値は変更不可(開発メモ)。並べるだけなのでそのまま繋ぐ
            lines.append(name + ": " + names.sorted().joined(separator: ","))
        }
        return lines
    }

    /// 新規インストールと、更新してきた DB のスキーマ定義そのものが一致する。
    /// 上の 2 つより細かく、`UNIQUE` などの制約や既定値の違いも見る。
    func testUpgradedSchemaMatchesFreshInstall() throws {
        let fresh = makeEmptyDatabase()
        defer { try? fresh.close() }
        try AppDatabase.prepare(fresh)
        let expected = schema(of: fresh)
        XCTAssertTrue(expected.count > 0)

        for startVersion in 0..<latestVersion() {
            let db = try makeDatabase(migratedUpTo: startVersion)
            defer { try? db.close() }

            try AppDatabase.prepare(db)

            XCTAssertEqual(expected, schema(of: db),
                           "バージョン \(startVersion) から上げた DB のスキーマが新規と違う")
        }
    }

    /// `sqlite_master` の中身を比較しやすい形にする(索引の自動生成分は `sql` が NULL)。
    private func schema(of db: SQLContext) -> [String] {
        let rows = (try? db.selectAll(sql: "SELECT name, sql FROM sqlite_master WHERE sql IS NOT NULL ORDER BY name")) ?? []
        var lines: [String] = []
        for row in rows {
            let name = row.first?.textValue ?? ""
            var sql = ""
            if row.count > 1 {
                sql = row[1].textValue ?? ""
            }
            lines.append(name + ": " + sql)
        }
        return lines
    }

    // MARK: - 既存データが生き残る

    /// 昔の DB に入っていた課題が、更新後も**リポジトリから読める**。
    ///
    /// 行が残っているだけでは足りない —— 今のデコーダで読めなければ画面には出ない。
    func testExistingIssueSurvivesTheUpgrade() throws {
        let db = try makeDatabase(migratedUpTo: 5)
        defer { try? db.close() }
        try db.exec(sql: """
            INSERT INTO issue (coach_words, done_form, created_at, updated_at)
            VALUES ('ハイクリアが浅い', 'ハイクリアが奥まで飛ぶ', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z')
            """)

        try AppDatabase.prepare(db)

        let issues = try IssueRepository(db: db).fetchAll()
        XCTAssertEqual(1, issues.count)
        var first: Issue = try XCTUnwrap(issues.first)
        XCTAssertEqual("ハイクリアが浅い", first.coachWords)
        XCTAssertEqual("ハイクリアが奥まで飛ぶ", first.doneForm)
    }

    /// 昔の DB に入っていた大会も同じ(`ALTER TABLE competition` を挟む)。
    func testExistingCompetitionSurvivesTheUpgrade() throws {
        let db = try makeDatabase(migratedUpTo: 5)
        defer { try? db.close() }
        try db.exec(sql: """
            INSERT INTO competition (name, event_date, created_at)
            VALUES ('県大会', '2026-09-07T00:00:00Z', '2026-01-01T00:00:00Z')
            """)

        try AppDatabase.prepare(db)

        let competitions = try CompetitionRepository(db: db).fetchAll()
        XCTAssertEqual(1, competitions.count)
        var first: Competition = try XCTUnwrap(competitions.first)
        XCTAssertEqual("県大会", first.name)
    }

    // MARK: - 後から足した列は NULL で始まる

    /// `ALTER TABLE ... ADD COLUMN` は既存行を消さず、**新しい列は NULL**。
    /// 既定値を付けると「まだ入力していない」と「その値を選んだ」が区別できなくなる。
    func testColumnsAddedLaterStartAsNullForExistingRows() throws {
        let db = try makeDatabase(migratedUpTo: 5)
        defer { try? db.close() }
        try db.exec(sql: """
            INSERT INTO issue (coach_words, created_at, updated_at)
            VALUES ('古い課題', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z')
            """)
        try db.exec(sql: """
            INSERT INTO competition (name, event_date, created_at)
            VALUES ('古い大会', '2026-09-07T00:00:00Z', '2026-01-01T00:00:00Z')
            """)

        try AppDatabase.prepare(db)

        // 6 本目で足した列(§3.2 レベルアップ提案を断った記録)
        let issueRows = try db.selectAll(sql: "SELECT level_up_declined_level FROM issue")
        XCTAssertEqual(1, issueRows.count)
        XCTAssertNil(issueRows.first?.first?.longValue)
        // 11 本目で足した列(§7.5 大会のねらい)
        let competitionRows = try db.selectAll(sql: "SELECT aim FROM competition")
        XCTAssertEqual(1, competitionRows.count)
        XCTAssertNil(competitionRows.first?.first?.textValue)
    }

    /// **役目を終えた設定は更新のときに消す。**
    ///
    /// 練習前の通知は曜日ではなく練習予定日(§5.2)で出すようになったので、
    /// `practice_reminder_weekdays` はもう誰も読まない。残すと `ExportRepository` が
    /// 書き出し続け、「設定は残っているのに曜日では鳴らない」状態になる。
    /// キーの定数は削除済みなので、ここでは生の文字列で書く。
    func testRetiredNotificationWeekdayKeyIsRemovedByTheUpgrade() throws {
        let db = try makeDatabase(migratedUpTo: 11)
        defer { try? db.close() }
        try db.exec(sql: "INSERT OR REPLACE INTO app_meta (key, value) VALUES ('practice_reminder_weekdays', '1,3,5')")

        try AppDatabase.prepare(db)

        let rows = try db.selectAll(sql: "SELECT value FROM app_meta WHERE key = 'practice_reminder_weekdays'")
        XCTAssertEqual(0, rows.count)
    }

    // MARK: - 何度呼んでも同じ

    /// `prepare` は接続を開くたびに呼ばれる。**2 回目以降は何もしない。**
    /// テーブルを作り直したりデータを消したりしない。
    func testPrepareIsIdempotent() throws {
        let db = makeEmptyDatabase()
        defer { try? db.close() }
        try AppDatabase.prepare(db)
        _ = try IssueRepository(db: db).create(coachWords: "ハイクリアが浅い")

        try AppDatabase.prepare(db)
        try AppDatabase.prepare(db)

        XCTAssertEqual(Int64(latestVersion()), db.userVersion)
        XCTAssertEqual(1, try IssueRepository(db: db).fetchAll().count)
    }

    /// **本人が変えた設定は更新をまたいで残る**(§4.2 の閾値)。
    ///
    /// `app_meta` ができるのは 8 本目なので、8 本目まで適用した DB で閾値を変えてから
    /// 最新まで上げる。既定に戻ると、stale の出方が黙って変わって気づきにくい。
    func testChangedSettingsSurviveTheUpgrade() throws {
        let db = try makeDatabase(migratedUpTo: 8)
        defer { try? db.close() }
        try AppMetaRepository(db: db).setStaleThresholds(StaleThresholds(days: 14, practiceCount: 3))

        try AppDatabase.prepare(db)

        let thresholds = try AppMetaRepository(db: db).staleThresholds()
        XCTAssertEqual(14, thresholds.days)
        XCTAssertEqual(3, thresholds.practiceCount)
    }

    // MARK: - 外部キー

    /// `prepare` は毎回 `PRAGMA foreign_keys = ON` を通る(**接続ごと**の設定)。
    /// 既に適用済みの DB でも、マイグレーションを飛ばして帰らないこと。
    func testPrepareTurnsOnForeignKeysEvenWhenAlreadyMigrated() throws {
        let db = try makeDatabase(migratedUpTo: latestVersion())
        defer { try? db.close() }
        try db.exec(sql: "PRAGMA foreign_keys = OFF")

        try AppDatabase.prepare(db)

        let rows = try db.selectAll(sql: "PRAGMA foreign_keys")
        XCTAssertEqual(Int64(1), rows.first?.first?.longValue)
    }
}
