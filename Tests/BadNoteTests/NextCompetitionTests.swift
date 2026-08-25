import XCTest
import Foundation
@testable import BadNote

/// 「次の大会」の選び方(§7.5 / ホーム)。
///
/// 目標大会が遠いとき、その手前にある大会に意味を持たせるために 1 件だけ選ぶ。
/// 目標大会そのものは除く(ホームでは別枠で大きく出ているため)。
final class NextCompetitionTests: XCTestCase {

    /// 2023-11-14T22:13:20Z。基準時刻。
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func day(_ offset: Int) -> Date {
        return Date(timeIntervalSince1970: 1_700_000_000 + Double(offset) * 86_400)
    }

    private func competition(_ id: Int64, _ name: String, _ eventDate: Date) -> Competition {
        return Competition(id: id, name: name, eventDate: eventDate, createdAt: t0)
    }

    func testPicksNearestFutureCompetition() {
        let list = [
            competition(1, "県大会", day(30)),
            competition(2, "市民大会", day(7)),
            competition(3, "地区大会", day(60)),
        ]

        let picked = NextCompetition.pick(upcoming: list, targetIds: [Int64](), asOf: t0)

        XCTAssertEqual(picked?.id, Int64(2))
    }

    /// 目標大会はホームで別枠なので候補から外す。
    func testExcludesTargetCompetition() {
        let list = [
            competition(1, "市民大会", day(7)),
            competition(2, "県大会", day(30)),
        ]

        let picked = NextCompetition.pick(upcoming: list, targetIds: [Int64(1)], asOf: t0)

        XCTAssertEqual(picked?.id, Int64(2))
    }

    /// 種目ごとに目標大会が違うときは、そのどれも候補にしない。
    func testExcludesEveryTarget() {
        let list = [
            competition(1, "市民大会", day(7)),
            competition(2, "県大会", day(30)),
            competition(3, "地区大会", day(60)),
        ]

        let picked = NextCompetition.pick(upcoming: list, targetIds: [Int64(1), Int64(2)], asOf: t0)

        XCTAssertEqual(picked?.id, Int64(3))
    }

    /// 終わった大会は選ばない。
    func testIgnoresPastCompetitions() {
        let list = [
            competition(1, "地区大会", day(-7)),
            competition(2, "県大会", day(14)),
        ]

        let picked = NextCompetition.pick(upcoming: list, targetIds: [Int64](), asOf: t0)

        XCTAssertEqual(picked?.id, Int64(2))
    }

    /// 当日の大会は「これから」に含む(当日いっぱいは先の予定として扱う)。
    func testIncludesCompetitionOnTheSameInstant() {
        let list = [competition(1, "県大会", t0)]

        let picked = NextCompetition.pick(upcoming: list, targetIds: [Int64](), asOf: t0)

        XCTAssertEqual(picked?.id, Int64(1))
    }

    func testReturnsNilWhenNothingRemains() {
        let list = [competition(1, "県大会", day(7))]

        XCTAssertNil(NextCompetition.pick(upcoming: list, targetIds: [Int64(1)], asOf: t0))
        XCTAssertNil(NextCompetition.pick(upcoming: [Competition](), targetIds: [Int64](), asOf: t0))
    }

    /// 同じ日に 2 つあるときは id の小さい方(先に登録した方)。並びを決めておかないと
    /// 開くたびに入れ替わって見える。
    func testBreaksTieByIdentifier() {
        let list = [
            competition(5, "後から登録", day(7)),
            competition(2, "先に登録", day(7)),
        ]

        let picked = NextCompetition.pick(upcoming: list, targetIds: [Int64](), asOf: t0)

        XCTAssertEqual(picked?.id, Int64(2))
    }
}
