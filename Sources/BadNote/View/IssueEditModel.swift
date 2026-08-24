import Foundation
import Observation
import SkipSQL

/// 課題の登録・編集画面の状態(§3)。
///
/// **新規で必須なのは `coachWords` の 1 行だけ。** 言い換え・タグ・影響度・コスト・
/// 種目・習熟度はすべて任意で、後から編集できる(§3.1 入力時に doneForm を強制しない)。
///
/// SQL は書かない。永続化は `IssueRepository` / `TagRepository` に任せる。
@Observable public final class IssueEditModel {

    /// 編集対象。nil なら新規。
    private let issueID: Int64?

    // MARK: - 入力

    /// もとの言葉(原文)。**編集しない**ので、既存の課題では読み取り専用にする。
    public var coachWords = ""
    public var doneForm = ""
    public var coachName = ""
    public var discipline: Discipline = .both
    public var masteryLevel: MasteryLevel = .solo
    public var impact: Int? = nil
    public var cost: Int? = nil
    public var tags: [Tag] = []
    public var tagDraft = ""

    // MARK: - 表示状態

    public var errorText: String? = nil
    public var isSaved = false

    private var database: SQLContext? = nil

    public init(issueID: Int64? = nil) {
        self.issueID = issueID
    }

    public var isNew: Bool {
        return issueID == nil
    }

    /// 原文が空だと何も残らないので、そこだけは要る。
    public var canSave: Bool {
        return !coachWords.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty
    }

    // MARK: - 読み込み

    public func load() {
        guard let issueID = issueID else {
            return
        }
        do {
            let db = try context()
            let issues = IssueRepository(db: db)
            guard let issue = try issues.fetch(id: issueID) else {
                errorText = "課題が見つかりません"
                return
            }
            coachWords = issue.coachWords
            doneForm = issue.doneForm ?? ""
            coachName = issue.coachName ?? ""
            discipline = issue.discipline
            masteryLevel = issue.masteryLevel
            impact = issue.impact
            cost = issue.cost
            tags = try TagRepository(db: db).fetchTags(issueId: issueID)
            errorText = nil
        } catch {
            errorText = "読み込みに失敗しました: \(error)"
        }
    }

    // MARK: - 入力操作

    /// 同じ値をもう一度押したら未設定に戻す。影響度もコストも任意なので。
    public func toggleImpact(_ value: Int) {
        impact = (impact == value) ? nil : value
    }

    public func toggleCost(_ value: Int) {
        cost = (cost == value) ? nil : value
    }

    /// タグを 1 つ足す。同名のタグがあれば既存のものを使う(重複は作らない)。
    public func addTag() {
        let name = tagDraft.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if name.isEmpty {
            return
        }
        do {
            let tag = try TagRepository(db: try context()).create(name: name)
            var alreadyAdded = false
            for existing in tags {
                if existing.id == tag.id {
                    alreadyAdded = true
                }
            }
            if !alreadyAdded {
                tags.append(tag)
            }
            tagDraft = ""
            errorText = nil
        } catch {
            errorText = "タグの追加に失敗しました: \(error)"
        }
    }

    public func removeTag(_ tag: Tag) {
        var remaining: [Tag] = []
        for existing in tags {
            if existing.id != tag.id {
                remaining.append(existing)
            }
        }
        tags = remaining
    }

    // MARK: - 保存

    /// 新規は `status = inbox` / `tier = someday` で作る(整理は後の工程)。
    public func save() {
        if !canSave {
            errorText = "気づいたことを 1 行入れてください"
            return
        }
        do {
            let db = try context()
            let issues = IssueRepository(db: db)
            let savedID: Int64

            if let issueID = issueID {
                guard var issue = try issues.fetch(id: issueID) else {
                    errorText = "課題が見つかりません"
                    return
                }
                // 原文は基本そのまま残すが、誤入力は直せる(2026-08-24 決定)
                issue.coachWords = coachWords.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                issue.doneForm = optionalText(doneForm)
                issue.coachName = optionalText(coachName)
                issue.discipline = discipline
                issue.masteryLevel = masteryLevel
                issue.impact = impact
                issue.cost = cost
                _ = try issues.update(issue)
                savedID = issueID
            } else {
                let created = try issues.create(coachWords: coachWords.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
                                                doneForm: optionalText(doneForm),
                                                coachName: optionalText(coachName),
                                                discipline: discipline,
                                                masteryLevel: masteryLevel,
                                                tier: .someday,
                                                impact: impact,
                                                cost: cost,
                                                status: .inbox)
                savedID = created.id
            }

            try TagRepository(db: db).setTags(tags, for: savedID)
            errorText = nil
            isSaved = true
        } catch {
            errorText = "保存に失敗しました: \(error)"
        }
    }

    private func optionalText(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func context() throws -> SQLContext {
        if let database = database {
            return database
        }
        let opened = try AppDatabase.open()
        database = opened
        return opened
    }
}
