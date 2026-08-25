import Foundation
import Observation
import SkipSQL

/// 大会一覧の状態(§7.5)。
///
/// これからの大会を日付順、下に終了した大会。目標大会には印を付ける。
@Observable public final class CompetitionListModel {

    /// 大会 1 件と、その種目エントリー。
    public struct Row: Identifiable, Hashable {
        public var competition: Competition
        public var entries: [CompetitionEntry]

        public var id: Int64 {
            return competition.id
        }

        /// 目標大会になっている種目。印の表示に使う。
        public var targetDisciplines: [Discipline] {
            var result: [Discipline] = []
            for entry in entries {
                if entry.isTarget {
                    result.append(entry.discipline)
                }
            }
            return result
        }
    }

    public private(set) var upcoming: [Row] = []
    public private(set) var finished: [Row] = []
    public var errorText: String? = nil


    public init() {
    }

    public func load(now: Date = Date()) {
        do {
            let db = try context()
            let repo = CompetitionRepository(db: db)
            // 当日の大会は当日いっぱい「これから」に残す
            let today = Calendar.current.startOfDay(for: now)
            // 終わった大会に「目標大会」のバッジが残らないようにする(§7.5)
            try repo.clearFinishedTargets(asOf: today)
            upcoming = try rows(for: try repo.fetchUpcoming(asOf: today), repo: repo)
            finished = try rows(for: try repo.fetchFinished(asOf: today), repo: repo)
            errorText = nil
        } catch {
            errorText = "大会の読み込みに失敗しました: \(error)"
        }
    }

    private func rows(for competitions: [Competition], repo: CompetitionRepository) throws -> [Row] {
        var result: [Row] = []
        for competition in competitions {
            result.append(Row(competition: competition,
                              entries: try repo.fetchEntries(competitionId: competition.id)))
        }
        return result
    }

    private func context() throws -> SQLContext {
        // 共有接続(6.3)。モデルごとに開くと database is locked を踏む
        return try AppDatabase.shared()
    }
}

/// 大会の登録・編集の状態(§7.5)。
@Observable public final class CompetitionEditModel {

    private let competitionID: Int64?

    public var name = ""
    public var eventDate = Date()
    public var venue = ""
    /// エントリーする種目と、それぞれ目標大会にするか
    public var entersSingles = false
    public var singlesIsTarget = false
    public var entersDoubles = false
    public var doublesIsTarget = false

    public var errorText: String? = nil
    public var isSaved = false


    public init(competitionID: Int64? = nil) {
        self.competitionID = competitionID
    }

    public var isNew: Bool {
        return competitionID == nil
    }

    public var canSave: Bool {
        return !name.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty
    }

    public func load() {
        guard let competitionID = competitionID else {
            return
        }
        do {
            let db = try context()
            let repo = CompetitionRepository(db: db)
            guard let competition = try repo.fetch(id: competitionID) else {
                errorText = "大会が見つかりません"
                return
            }
            name = competition.name
            eventDate = competition.eventDate
            venue = competition.venue ?? ""
            for entry in try repo.fetchEntries(competitionId: competitionID) {
                if entry.discipline == Discipline.singles {
                    entersSingles = true
                    singlesIsTarget = entry.isTarget
                } else if entry.discipline == Discipline.doubles {
                    entersDoubles = true
                    doublesIsTarget = entry.isTarget
                }
            }
            errorText = nil
        } catch {
            errorText = "読み込みに失敗しました: \(error)"
        }
    }

    public func save() {
        if !canSave {
            errorText = "大会の名前を入れてください"
            return
        }
        do {
            let repo = CompetitionRepository(db: try context())
            let trimmedName = name.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            let trimmedVenue = venue.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            // 目標にするのは、その種目にエントリーしている場合だけ
            var entries: [CompetitionEntry] = []
            if entersSingles {
                entries.append(CompetitionEntry(discipline: .singles, isTarget: singlesIsTarget))
            }
            if entersDoubles {
                entries.append(CompetitionEntry(discipline: .doubles, isTarget: doublesIsTarget))
            }

            if let competitionID = competitionID {
                guard var competition = try repo.fetch(id: competitionID) else {
                    errorText = "大会が見つかりません"
                    return
                }
                competition.name = trimmedName
                competition.eventDate = eventDate
                competition.venue = trimmedVenue.isEmpty ? nil : trimmedVenue
                _ = try repo.update(competition, entries: entries)
            } else {
                _ = try repo.create(name: trimmedName,
                                    eventDate: eventDate,
                                    venue: trimmedVenue.isEmpty ? nil : trimmedVenue,
                                    entries: entries)
            }
            errorText = nil
            isSaved = true
        } catch {
            errorText = "保存に失敗しました: \(error)"
        }
    }

    private func context() throws -> SQLContext {
        // 共有接続(6.3)。モデルごとに開くと database is locked を踏む
        return try AppDatabase.shared()
    }
}
