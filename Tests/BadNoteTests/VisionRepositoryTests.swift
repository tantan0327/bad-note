import XCTest
import Foundation
import SkipSQL
@testable import BadNote

/// `VisionRepository` の仕様。`vision` テーブルは 1 レコードのみ(§6)。
///
/// - 未保存でも `fetch()` は nil を返さない。空の `Vision` を返して呼び出し側の分岐を無くす
/// - 保存は常に同じ行の更新。何度保存しても 2 行目は作らない
/// - DB はテストごとに新規のインメモリ(`SQLContext(configuration: .platform)`)
final class VisionRepositoryTests: XCTestCase {

    /// 2023-11-14T22:13:20Z
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    /// t0 の 1 時間後 = 2023-11-14T23:13:20Z
    private let t1 = Date(timeIntervalSince1970: 1_700_003_600)

    private var clock = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeDatabase() throws -> SQLContext {
        let db = SQLContext(configuration: .platform)
        try AppDatabase.prepare(db)
        return db
    }

    private func makeRepository(_ db: SQLContext) -> VisionRepository {
        clock = t0
        return VisionRepository(db: db, now: { self.clock })
    }

    private func rowCount(_ db: SQLContext) throws -> Int64 {
        let rows = try db.selectAll(sql: "SELECT COUNT(*) FROM vision")
        return try XCTUnwrap(rows.first?.first?.longValue)
    }

    // MARK: - 未保存の状態

    /// 未保存でも nil を返さない。呼び出し側に「まだ無い」の分岐を作らせない。
    func testFetchReturnsEmptyVisionWhenNeverSaved() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let vision = try repo.fetch()

        XCTAssertEqual(Vision(), vision)
    }

    func testEmptyVisionHasBlankBody() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let vision = try repo.fetch()

        XCTAssertEqual("", vision.body)
        XCTAssertNil(vision.imagePath)
    }

    /// 一度も保存していないことは `updatedAt` が nil であることで分かる。
    /// §7.1「めざす姿が空 → 初回は促さない。数回使った後に 1 度だけ促す」の判断材料。
    func testEmptyVisionHasNoUpdatedAt() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let vision = try repo.fetch()

        XCTAssertNil(vision.updatedAt)
    }

    func testEmptyVisionIsEmpty() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let vision = try repo.fetch()

        XCTAssertTrue(vision.isEmpty)
    }

    /// 未保存の間は行を作らない。`fetch()` が副作用で INSERT しないこと。
    func testFetchDoesNotCreateRow() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        _ = try repo.fetch()

        XCTAssertEqual(Int64(0), try rowCount(db))
    }

    // MARK: - 保存

    func testSaveStoresBody() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        _ = try repo.save(Vision(body: "相手に的を絞らせないシングルスプレーヤー"))

        let vision = try repo.fetch()
        XCTAssertEqual("相手に的を絞らせないシングルスプレーヤー", vision.body)
    }

    func testSaveStoresImagePath() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        _ = try repo.save(Vision(body: "めざす姿", imagePath: "vision/photo.jpg"))

        let vision = try repo.fetch()
        XCTAssertEqual("vision/photo.jpg", vision.imagePath)
    }

    func testSaveAllowsNilImagePath() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        _ = try repo.save(Vision(body: "めざす姿"))

        let vision = try repo.fetch()
        XCTAssertNil(vision.imagePath)
    }

    func testSaveTakesUpdatedAtFromClock() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let saved = try repo.save(Vision(body: "めざす姿"))

        XCTAssertEqual(t0, saved.updatedAt)
    }

    func testSaveReturnsStoredVision() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        let saved = try repo.save(Vision(body: "めざす姿", imagePath: "vision/photo.jpg"))

        let fetched = try repo.fetch()
        XCTAssertEqual(saved, fetched, "save の戻り値と fetch の結果が一致すること")
    }

    /// §4.2 タイムスタンプは UTC の ISO 8601 TEXT で統一する。
    func testUpdatedAtIsStoredAsUTCISO8601Text() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        _ = try repo.save(Vision(body: "めざす姿"))

        let rows = try db.selectAll(sql: "SELECT updated_at FROM vision")
        let storedText = try XCTUnwrap(rows.first?.first?.textValue)
        XCTAssertEqual("2023-11-14T22:13:20Z", storedText)
    }

    // MARK: - 常に同じ 1 行

    func testSaveCreatesExactlyOneRow() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        _ = try repo.save(Vision(body: "めざす姿"))

        XCTAssertEqual(Int64(1), try rowCount(db))
    }

    /// 何度保存しても 2 行目は作らない。
    func testRepeatedSavesKeepSingleRow() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        _ = try repo.save(Vision(body: "1回目"))
        _ = try repo.save(Vision(body: "2回目"))
        _ = try repo.save(Vision(body: "3回目"))

        XCTAssertEqual(Int64(1), try rowCount(db))
    }

    func testSaveOverwritesPreviousVision() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        _ = try repo.save(Vision(body: "1回目"))
        _ = try repo.save(Vision(body: "2回目"))

        let vision = try repo.fetch()
        XCTAssertEqual("2回目", vision.body)
    }

    /// 保存のたびに行が入れ替わっても id は固定。
    func testSaveAlwaysUsesTheSameRowIdentifier() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        _ = try repo.save(Vision(body: "1回目"))
        let firstRows = try db.selectAll(sql: "SELECT id FROM vision")
        let firstID = try XCTUnwrap(firstRows.first?.first?.longValue)
        _ = try repo.save(Vision(body: "2回目"))
        let secondRows = try db.selectAll(sql: "SELECT id FROM vision")
        let secondID = try XCTUnwrap(secondRows.first?.first?.longValue)

        XCTAssertEqual(firstID, secondID)
    }

    func testSaveRefreshesUpdatedAt() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        _ = try repo.save(Vision(body: "1回目"))
        clock = t1
        _ = try repo.save(Vision(body: "2回目"))

        let vision = try repo.fetch()
        XCTAssertEqual(t1, vision.updatedAt)
    }

    /// 本文を消す操作。空文字で上書きできること(前の本文が残らない)。
    func testSaveClearsBodyWhenGivenEmptyString() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        _ = try repo.save(Vision(body: "めざす姿"))
        _ = try repo.save(Vision(body: ""))

        let vision = try repo.fetch()
        XCTAssertEqual("", vision.body)
    }

    /// 画像だけ外す操作。
    func testSaveClearsImagePathWhenGivenNil() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        _ = try repo.save(Vision(body: "めざす姿", imagePath: "vision/photo.jpg"))
        _ = try repo.save(Vision(body: "めざす姿", imagePath: nil))

        let vision = try repo.fetch()
        XCTAssertNil(vision.imagePath)
    }

    // MARK: - isEmpty

    func testSavedVisionIsNotEmpty() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        _ = try repo.save(Vision(body: "めざす姿"))

        let vision = try repo.fetch()
        XCTAssertFalse(vision.isEmpty)
    }

    /// 本文が空でも画像があれば「空」ではない。
    func testVisionWithOnlyImageIsNotEmpty() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        _ = try repo.save(Vision(body: "", imagePath: "vision/photo.jpg"))

        let vision = try repo.fetch()
        XCTAssertFalse(vision.isEmpty)
    }

    /// 保存済みでも中身を消したら「空」に戻る。
    func testClearedVisionIsEmptyAgain() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        _ = try repo.save(Vision(body: "めざす姿", imagePath: "vision/photo.jpg"))
        _ = try repo.save(Vision(body: "", imagePath: nil))

        let vision = try repo.fetch()
        XCTAssertTrue(vision.isEmpty)
    }

    /// 中身は空でも保存した事実は残る(`updatedAt` が入る)。
    func testClearedVisionKeepsUpdatedAt() throws {
        let db = try makeDatabase()
        defer { try? db.close() }
        let repo = makeRepository(db)

        _ = try repo.save(Vision(body: "めざす姿"))
        clock = t1
        _ = try repo.save(Vision(body: ""))

        let vision = try repo.fetch()
        XCTAssertEqual(t1, vision.updatedAt)
    }
}
