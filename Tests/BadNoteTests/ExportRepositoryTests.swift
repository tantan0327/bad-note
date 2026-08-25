import XCTest
import Foundation
import SkipSQL
@testable import BadNote

/// `ExportRepository` の仕様(tasks.md 7.3 データの書き出し)。
///
/// - 全テーブルの生の値を JSON 1 つに写す(解釈も変換もしない)
/// - 出力は決定的(同じ DB と時刻なら同じ文字列)
/// - DB はテストごとに新規のインメモリ(`SQLContext(configuration: .platform)`)
final class ExportRepositoryTests: XCTestCase {

    /// 2023-11-14T22:13:20Z
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeDatabase() throws -> SQLContext {
        let db = SQLContext(configuration: .platform)
        try AppDatabase.prepare(db)
        return db
    }

    // MARK: - 形式

    func testExportHasEnvelope() throws {
        let db = try makeDatabase()
        defer { try? db.close() }

        let json = try ExportRepository(db: db).exportJSON(now: t0)

        XCTAssertTrue(json.contains("\"app\": \"BadNote\""))
        XCTAssertTrue(json.contains("\"format\": 1"))
        // マイグレーションを足すたびに書き換えずに済むよう DB から取る
        XCTAssertTrue(json.contains("\"schema_version\": \(db.userVersion)"))
        XCTAssertTrue(db.userVersion > 0)
        XCTAssertTrue(json.contains("\"exported_at\": \"2023-11-14T22:13:20Z\""))
    }

    /// 空の DB でも全テーブルのキーが出る(復元側が欠けたキーを心配しないで済む)
    func testExportListsEveryTableWhenEmpty() throws {
        let db = try makeDatabase()
        defer { try? db.close() }

        let json = try ExportRepository(db: db).exportJSON(now: t0)

        for table in ExportRepository.tables {
            XCTAssertTrue(json.contains("\"\(table)\":"), "テーブル \(table) が出力に無い")
        }
    }

    /// マイグレーションでテーブルを足したのに書き出し対象に入れ忘れる事故を防ぐ。
    /// 実際のスキーマ(sqlite_master)と `ExportRepository.tables` を突き合わせる。
    func testTableListMatchesSchema() throws {
        let db = try makeDatabase()
        defer { try? db.close() }

        let rows = try db.selectAll(sql: """
            SELECT name FROM sqlite_master
            WHERE type = 'table' AND name NOT LIKE 'sqlite_%'
            ORDER BY name
            """)
        var actual: [String] = []
        for row in rows {
            if let name = row.first?.textValue {
                actual.append(name)
            }
        }
        let exported = ExportRepository.tables.sorted()
        XCTAssertEqual(exported, actual)
    }

    // MARK: - 中身

    /// app_meta の初期値 4 行は空の DB でも書き出される
    func testExportContainsAppMetaDefaults() throws {
        let db = try makeDatabase()
        defer { try? db.close() }

        let json = try ExportRepository(db: db).exportJSON(now: t0)

        XCTAssertTrue(json.contains("\"key\": \"stale_days\""))
        XCTAssertTrue(json.contains("\"value\": \"21\""))
    }

    func testExportContainsSeededRows() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let issues = IssueRepository(db: db, now: { self.t0 })
        let issue = try issues.create(coachWords: "ラケット面が下向き", tier: .focus, status: .active)
        let tags = TagRepository(db: db)
        let tag = try tags.create(name: "ネット前")
        try tags.attach(tagId: tag.id, to: issue.id)
        let practices = PracticeRepository(db: db, now: { self.t0 })
        _ = try practices.create(practiceDate: t0, minutes: 90, kind: nil,
                                 focus: [FocusEntry(issueId: issue.id, result: .done)])

        let json = try ExportRepository(db: db).exportJSON(now: t0)

        XCTAssertTrue(json.contains("\"coach_words\": \"ラケット面が下向き\""))
        XCTAssertTrue(json.contains("\"name\": \"ネット前\""))
        XCTAssertTrue(json.contains("\"minutes\": 90"))
        XCTAssertTrue(json.contains("\"result\": \"done\""))
    }

    /// NULL の列は JSON の null になる(空文字にしない。復元で区別が要る)
    func testExportKeepsNullColumns() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let issues = IssueRepository(db: db, now: { self.t0 })
        _ = try issues.create(coachWords: "クリアが浅い")

        let json = try ExportRepository(db: db).exportJSON(now: t0)

        XCTAssertTrue(json.contains("\"done_form\": null"))
    }

    // MARK: - エスケープ

    /// 引用符・改行・バックスラッシュ・タブが JSON として正しく逃がされる
    func testExportEscapesTextValues() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let issues = IssueRepository(db: db, now: { self.t0 })
        _ = try issues.create(coachWords: "面を\"上\"に\n2行目\\目\tおわり")

        let json = try ExportRepository(db: db).exportJSON(now: t0)

        XCTAssertTrue(json.contains("面を\\\"上\\\"に\\n2行目\\\\目\\tおわり"))
    }

    func testEscapeString() {
        XCTAssertEqual(ExportRepository.escape("素直な文"), "素直な文")
        XCTAssertEqual(ExportRepository.escape("a\"b"), "a\\\"b")
        XCTAssertEqual(ExportRepository.escape("a\\b"), "a\\\\b")
        XCTAssertEqual(ExportRepository.escape("a\nb"), "a\\nb")
        XCTAssertEqual(ExportRepository.escape("a\rb"), "a\\rb")
        XCTAssertEqual(ExportRepository.escape("a\tb"), "a\\tb")
    }

    // MARK: - 決定性と構文

    /// 同じ DB と時刻なら同じ文字列。差分でバックアップを比べられる
    func testExportIsDeterministic() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let issues = IssueRepository(db: db, now: { self.t0 })
        _ = try issues.create(coachWords: "サーブが浮く")

        let repository = ExportRepository(db: db)
        let first = try repository.exportJSON(now: t0)
        let second = try repository.exportJSON(now: t0)

        XCTAssertEqual(first, second)
    }

    /// 出力は JSON として解析できる(壊れたバックアップは作らない)
    func testExportIsParseableJSON() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let issues = IssueRepository(db: db, now: { self.t0 })
        _ = try issues.create(coachWords: "面を\"上\"に\n2行目")

        let json = try ExportRepository(db: db).exportJSON(now: t0)

        let data: Data = try XCTUnwrap(json.data(using: String.Encoding.utf8))
        let parsed = try JSONSerialization.jsonObject(with: data)
        let object: [String: Any] = try XCTUnwrap(parsed as? [String: Any])
        XCTAssertEqual(object["app"] as? String, "BadNote")
    }
}
