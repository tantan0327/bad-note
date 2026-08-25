import Foundation

/// 大会(§6 `competition`)。目標とする試合。
public struct Competition: Hashable, Identifiable {
    public var id: Int64
    public var name: String
    /// 開催日。§4.2 の比較とカウントダウン(§7.1)のため UTC の ISO 8601 で保存する。
    public var eventDate: Date
    public var venue: String?
    /// この大会でのねらい(§7.5)。**目標大会でなくても持てる。**
    /// 大会版の小さな「めざす姿」で、振り返り(後)の対になる前の記録。任意。
    public var aim: String?
    public var createdAt: Date

    public init(id: Int64,
                name: String,
                eventDate: Date,
                venue: String? = nil,
                aim: String? = nil,
                createdAt: Date) {
        self.id = id
        self.name = name
        self.eventDate = eventDate
        self.venue = venue
        self.aim = aim
        self.createdAt = createdAt
    }
}

/// 大会のエントリー種目(§6 `competition_entry`)。1 大会が複数種目を持てる。
///
/// `discipline` に `both` は使えない(課題の既定値であって、出場する種目ではない)。
/// `isTarget` は種目ごとに最大 1 件で、`CompetitionRepository` が担保する。
public struct CompetitionEntry: Hashable {
    public var discipline: Discipline
    public var isTarget: Bool

    public init(discipline: Discipline, isTarget: Bool = false) {
        self.discipline = discipline
        self.isTarget = isTarget
    }
}
