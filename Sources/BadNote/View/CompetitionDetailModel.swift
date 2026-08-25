import Foundation
import Observation
import SkipSQL

/// 大会詳細の状態(§7.5)。
@Observable public final class CompetitionDetailModel {

    /// 種目ごとのセクション。
    public struct DisciplineSection: Identifiable, Hashable {
        public var discipline: Discipline
        public var isTarget: Bool
        /// この大会までに取り組む課題
        public var issues: [Issue]
        /// 残り時間に対してコストが重い課題の id(§7.5 控えめに提示する)
        public var tightIssueIds: [Int64]

        public var id: String {
            return discipline.rawValue
        }

        public func isTight(_ issue: Issue) -> Bool {
            for id in tightIssueIds {
                if id == issue.id {
                    return true
                }
            }
            return false
        }
    }

    /// 振り返りの入力(種目ごとに 1 セット)。
    public struct ReviewInput: Identifiable, Hashable {
        public var discipline: Discipline
        public var result = ""
        public var wentWell = ""
        public var nextAction = ""
        public var neededResources = ""

        public var id: String {
            return discipline.rawValue
        }
    }

    private let competitionID: Int64

    public private(set) var competition: Competition? = nil
    public private(set) var sections: [DisciplineSection] = []
    public private(set) var remainingDays = 0
    /// 推定できないときは nil(§5.2)
    public private(set) var remainingPractices: Int? = nil
    /// §4.4 調整期の帯
    public private(set) var isAdjustmentPeriod = false
    /// 当日を過ぎたら振り返りのフォームに切り替える(§7.5)
    public private(set) var isFinished = false
    public var reviews: [ReviewInput] = []

    public var errorText: String? = nil
    public var savedMessage: String? = nil


    public init(competitionID: Int64) {
        self.competitionID = competitionID
    }

    public func load(now: Date = Date()) {
        do {
            let db = try context()
            let competitions = CompetitionRepository(db: db)
            guard let loaded = try competitions.fetch(id: competitionID) else {
                errorText = "大会が見つかりません"
                return
            }
            competition = loaded

            // 日付の境界は「今日の 0 時」で揃える
            let today = Calendar.current.startOfDay(for: now)
            remainingDays = Int(loaded.eventDate.timeIntervalSince(today) / 86_400.0)
            isFinished = remainingDays < 0
            isAdjustmentPeriod = AdjustmentPeriod.isActive(targets: [loaded], asOf: today)

            var practiceDates: [Date] = []
            for practice in try PracticeRepository(db: db).fetchAll() {
                practiceDates.append(practice.practiceDate)
            }
            remainingPractices = PracticeForecast.remainingPracticeCount(practiceDates: practiceDates,
                                                                        eventDate: loaded.eventDate,
                                                                        asOf: today)

            try loadSections(db: db, competitions: competitions)
            try loadReviews(competitions: competitions)
            errorText = nil
        } catch {
            errorText = "読み込みに失敗しました: \(error)"
        }
    }

    // MARK: - ねらい(§7.5。目標大会でなくても持てる)

    /// 編集中のねらい。シートの表示フラグは View 側の @State が持つ。
    public var aimText = ""

    public func beginEditingAim() {
        aimText = competition?.aim ?? ""
    }

    /// ねらいを保存する。空にしたら未記入に戻す(消せること)。
    public func saveAim() {
        guard var target = competition else {
            return
        }
        do {
            let db = try context()
            let competitions = CompetitionRepository(db: db)
            let trimmed = aimText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            var value: String? = nil
            if !trimmed.isEmpty {
                value = trimmed
            }
            target.aim = value
            // update はエントリーを集合で置き換えるので、今の内容をそのまま渡す
            let entries = try competitions.fetchEntries(competitionId: competitionID)
            competition = try competitions.update(target, entries: entries)
            errorText = nil
        } catch {
            errorText = "ねらいの保存に失敗しました: \(error)"
        }
    }

    /// §7.5 種目ごとにセクション分け。**`both` の課題は両方に出す。**
    private func loadSections(db: SQLContext, competitions: CompetitionRepository) throws {
        let issues = IssueRepository(db: db)
        var result: [DisciplineSection] = []
        for entry in try competitions.fetchEntries(competitionId: competitionID) {
            let linked = try issues.fetch(statuses: [.inbox, .active],
                                          competitionId: competitionID,
                                          discipline: entry.discipline)
            var tight: [Int64] = []
            for issue in linked {
                if CompetitionFeasibility.isTight(cost: issue.cost, remainingDays: remainingDays) {
                    tight.append(issue.id)
                }
            }
            result.append(DisciplineSection(discipline: entry.discipline,
                                            isTarget: entry.isTarget,
                                            issues: linked,
                                            tightIssueIds: tight))
        }
        sections = result
    }

    private func loadReviews(competitions: CompetitionRepository) throws {
        var inputs: [ReviewInput] = []
        for section in sections {
            var input = ReviewInput(discipline: section.discipline)
            if let stored = try competitions.fetchReview(competitionId: competitionID, discipline: section.discipline) {
                input.result = stored.result ?? ""
                input.wentWell = stored.wentWell ?? ""
                input.nextAction = stored.nextAction ?? ""
                input.neededResources = stored.neededResources ?? ""
            }
            inputs.append(input)
        }
        reviews = inputs
    }

    // MARK: - 操作

    public func saveReview(_ input: ReviewInput) {
        do {
            try CompetitionRepository(db: try context()).saveReview(competitionId: competitionID,
                                                                    discipline: input.discipline,
                                                                    result: optional(input.result),
                                                                    wentWell: optional(input.wentWell),
                                                                    nextAction: optional(input.nextAction),
                                                                    neededResources: optional(input.neededResources))
            savedMessage = "振り返りを保存しました"
            errorText = nil
        } catch {
            errorText = "保存に失敗しました: \(error)"
        }
    }

    /// §7.5 3 つ目の回答からそのまま課題を登録する。未整理として作る。
    public func createIssueFromNextAction(_ input: ReviewInput) {
        let words = input.nextAction.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if words.isEmpty {
            return
        }
        do {
            let db = try context()
            let created = try IssueRepository(db: db).create(coachWords: words, discipline: input.discipline)
            // 作った課題はこの大会に紐付けておく
            var ids = try CompetitionRepository(db: db).fetchIssueIds(competitionId: competitionID)
            ids.append(created.id)
            try CompetitionRepository(db: db).setIssues(ids, for: competitionID)
            savedMessage = "課題として登録しました"
            load()
        } catch {
            errorText = "課題の登録に失敗しました: \(error)"
        }
    }

    public func delete() {
        do {
            try CompetitionRepository(db: try context()).delete(id: competitionID)
            errorText = nil
        } catch {
            errorText = "削除に失敗しました: \(error)"
        }
    }

    private func optional(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func context() throws -> SQLContext {
        // 共有接続(6.3)。モデルごとに開くと database is locked を踏む
        return try AppDatabase.shared()
    }
}
