import XCTest
import Foundation
@testable import BadNote

/// 家トレの日付の保存形式(§10.4)。
///
/// **`TrainingRepository` のテストだけでは書式の変化に気づけない** ——
/// 同じ `DayStamp` で書いて同じ `DayStamp` で読むので、書式を変えても往復は成立してしまう。
/// `SQLTimestamp` は保存文字列そのものを検査するテストで守られている
/// (`testEventDateIsStoredAsUTCISO8601Text` など)ので、こちらも同じ守り方をする。
final class DayStampTests: XCTestCase {

    /// **ローカルの暦日**を組み立てる。`DayStamp` はタイムゾーンを固定しない
    /// (「その日やったか」の単位はローカルの暦日)ので、期待値もローカルで作る。
    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return Calendar.current.date(from: components) ?? Date()
    }

    // MARK: - 書式

    func testFormatsAsYearMonthDay() {
        XCTAssertEqual(DayStamp().text(from: date(2026, 8, 22)), "2026-08-22")
    }

    /// **月と日はゼロ埋めする。** 埋めないと辞書順が日付順にならない
    /// (`2026-1-4` は `2026-12-31` より後ろに並んでしまう)。
    func testPadsMonthAndDay() {
        XCTAssertEqual(DayStamp().text(from: date(2026, 1, 4)), "2026-01-04")
    }

    /// 西暦で出す。和暦(`R08-08-22`)になると `training_date` が壊れるので、
    /// `en_US_POSIX` + グレゴリオ暦の指定を外させない。
    func testUsesGregorianYear() {
        XCTAssertTrue(DayStamp().text(from: date(2026, 8, 22)).hasPrefix("2026"))
    }

    // MARK: - 暦日であってタイムスタンプではない

    /// 同じ日なら時刻が違っても同じ文字列。
    /// **ここにタイムゾーンを固定すると壊れる** —— UTC に固定すると、
    /// 日本の朝 9 時より前のチェックが前日の記録になってしまう。
    func testSameLocalDayRegardlessOfTime() {
        let stamp = DayStamp()

        XCTAssertEqual(stamp.text(from: date(2026, 8, 22, hour: 0)),
                       stamp.text(from: date(2026, 8, 22, hour: 23)))
    }

    /// 月をまたぐ境界。0 時台でも当日になる(前月末に落ちない)。
    func testCrossesToNextLocalDay() {
        XCTAssertEqual(DayStamp().text(from: date(2026, 3, 1, hour: 0)), "2026-03-01")
    }

    // MARK: - 文字列から戻す(§5.2 練習予定日)

    /// 書いた文字列から**同じ暦日**に戻せる。
    /// 練習予定日は保存文字列を id にして削除するので、往復が崩れると消せなくなる。
    func testParsesBackToTheSameDay() {
        let stamp = DayStamp()
        let original = date(2026, 1, 4)

        let parsed: Date = stamp.date(from: stamp.text(from: original)) ?? Date()

        XCTAssertEqual(stamp.text(from: original), stamp.text(from: parsed))
    }

    /// 戻した日付は**その日の 0 時**。数え上げの区間の端に使うので時刻を持たせない。
    func testParsedDayStartsAtMidnight() {
        let stamp = DayStamp()

        let parsed: Date = stamp.date(from: "2026-03-01") ?? Date()

        let components = Calendar.current.dateComponents([Calendar.Component.hour,
                                                          Calendar.Component.minute],
                                                         from: parsed)
        XCTAssertEqual(0, components.hour)
        XCTAssertEqual(0, components.minute)
    }

    /// 読めない文字列は nil。壊れた行を「今日」として扱わない。
    func testReturnsNilForUnreadableText() {
        let stamp = DayStamp()

        XCTAssertNil(stamp.date(from: ""))
        XCTAssertNil(stamp.date(from: "2026-13-45"))
        XCTAssertNil(stamp.date(from: "きのう"))
    }

    // MARK: - 並び

    /// **辞書順の比較 = 日付順の比較。**
    /// 期間の集計(`training_date >= ? AND training_date < ?`)がこれに乗っている。
    func testLexicographicOrderMatchesDateOrder() {
        let stamp = DayStamp()
        let older = stamp.text(from: date(2025, 12, 31))
        let middle = stamp.text(from: date(2026, 1, 1))
        let newer = stamp.text(from: date(2026, 10, 5))

        XCTAssertTrue(older < middle)
        XCTAssertTrue(middle < newer)
    }
}
