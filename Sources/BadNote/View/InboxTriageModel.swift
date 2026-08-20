import Foundation
import Observation
import SkipSQL

/// インボックス整理画面の状態(§3.1 の「後日の整理フェーズ」)。
///
/// 練習後は `coachWords` の 1 行だけで登録できる代わりに、言い換えと属性付けは
/// この画面でまとめて行う。**1 件ずつ順に処理する** —— 一覧で眺めると手が止まるため。
///
/// SQL は書かない。永続化は `IssueRepository` / `TagRepository` に任せる。
@Observable public final class InboxTriageModel {

    /// 開いた時点の未整理の課題。処理中に増減させない(足元が動くと迷子になる)。
    public private(set) var queue: [Issue] = []
    public private(set) var index = 0
    /// この整理で `active` にした件数。
    public private(set) var organizedCount = 0

    // MARK: - 入力

    public var doneForm = ""
    public var discipline: Discipline = .both
    public var impact: Int? = nil
    public var cost: Int? = nil
    public var tags: [Tag] = []
    public var tagDraft = ""

    // MARK: - 表示状態

    public var errorText: String? = nil
    public var isShowingDeleteConfirmation = false

    private var database: SQLContext? = nil

    public init() {
    }

    /// 今処理している課題。すべて処理し終えたら nil。
    public var current: Issue? {
        if index < queue.count {
            return queue[index]
        }
        return nil
    }

    public var isFinished: Bool {
        return index >= queue.count
    }

    /// この課題を含む残り件数。「3 件中 2 件目」の分母ではなく、あと何件かを出す。
    public var remainingCount: Int {
        let remaining = queue.count - index
        return remaining > 0 ? remaining : 0
    }

    // MARK: - 読み込み

    public func load() {
        do {
            let issues = IssueRepository(db: try context())
            queue = try issues.fetch(statuses: [.inbox])
            index = 0
            organizedCount = 0
            loadInputs()
            errorText = nil
        } catch {
            errorText = "未整理の課題の読み込みに失敗しました: \(error)"
        }
    }

    // MARK: - 入力操作

    public func toggleImpact(_ value: Int) {
        impact = (impact == value) ? nil : value
    }

    public func toggleCost(_ value: Int) {
        cost = (cost == value) ? nil : value
    }

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

    // MARK: - 3 つの出口

    /// 整理して `active` にする。入力は任意で、`doneForm` が空でも通す。
    public func organize() {
        guard let issue = current else {
            return
        }
        do {
            let db = try context()
            var edited = issue
            edited.doneForm = optionalText(doneForm)
            edited.discipline = discipline
            edited.impact = impact
            edited.cost = cost
            edited.status = .active
            _ = try IssueRepository(db: db).update(edited)
            try TagRepository(db: db).setTags(tags, for: issue.id)
            organizedCount += 1
            errorText = nil
            advance()
        } catch {
            errorText = "保存に失敗しました: \(error)"
        }
    }

    /// 今は決めない。`inbox` のまま次へ送る。
    public func skip() {
        advance()
    }

    /// もう不要。課題そのものを消す。
    public func delete() {
        guard let issue = current else {
            return
        }
        do {
            try IssueRepository(db: try context()).delete(id: issue.id)
            errorText = nil
            advance()
        } catch {
            errorText = "削除に失敗しました: \(error)"
        }
    }

    // MARK: - 内部

    private func advance() {
        index += 1
        loadInputs()
    }

    /// 次の課題の既存の値を入力欄に移す。
    private func loadInputs() {
        guard let issue = current else {
            doneForm = ""
            discipline = .both
            impact = nil
            cost = nil
            tags = []
            tagDraft = ""
            return
        }
        doneForm = issue.doneForm ?? ""
        discipline = issue.discipline
        impact = issue.impact
        cost = issue.cost
        tagDraft = ""
        do {
            tags = try TagRepository(db: try context()).fetchTags(issueId: issue.id)
        } catch {
            tags = []
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
