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

    /// 画面に出る**ただ 1 つの行**(2026-10-12)。
    ///
    /// 新規ならこれが書き留めた言葉になり、編集なら言い換えに入る
    /// (`IssueTitleEdit`)。**どちらの画面でも欄は 1 つ。**
    public var title = ""

    /// 書き留めた言葉(原文)。編集画面の折りたたみの中にだけ出す。
    /// 誤入力は直せる(2026-08-24 決定)ので読み取り専用にはしない。
    public var coachWords = ""

    /// 画面を開いた時点の 1 行。**触ったかどうかの判定にだけ使う**(2026-10-18)。
    /// これが無いと、もとの言葉の誤字を直したときに
    /// 直す前の文が言い換えとして保存される。
    private var loadedTitle = ""
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


    public init(issueID: Int64? = nil) {
        self.issueID = issueID
    }

    public var isNew: Bool {
        return issueID == nil
    }

    /// 1 行が空だと何も残らないので、そこだけは要る。
    public var canSave: Bool {
        return !title.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty
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
            // 画面に出すのは 1 行だけ。言い換えがあればそれ、無ければ書き留めた言葉
            title = IssueTitleEdit.title(of: issue)
            loadedTitle = title
            coachWords = issue.coachWords
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

    /// 新規は `status = active` / `tier = someday` で作る。
    ///
    /// 追加画面で書いた課題は**整理済み**(この画面が整理と同じ項目を持つ。
    /// 未整理に積み直すと二度手間になる。2026-08-24)。整理(インボックス)を
    /// 通るのは練習ログや大会振り返りの 1 行キャプチャだけ。
    public func save() {
        if !canSave {
            errorText = "課題を 1 行入れてください"
            return
        }
        // 編集では `coachWords` を空にできない(折りたたみの中で消された場合に備える)
        if !isNew && coachWords.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
            coachWords = title
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
                // **直した 1 行は言い換えに入る。書き留めた言葉は残る**(2026-10-12)
                issue = IssueTitleEdit.applied(to: issue, title: title, originalTitle: loadedTitle)
                issue.coachName = optionalText(coachName)
                issue.discipline = discipline
                issue.masteryLevel = masteryLevel
                issue.impact = impact
                issue.cost = cost
                _ = try issues.update(issue)
                savedID = issueID
            } else {
                // 新規はその 1 行が書き留めた言葉そのもの。言い換えは持たせない
                let created = try issues.create(coachWords: title.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
                                                doneForm: nil,
                                                coachName: optionalText(coachName),
                                                discipline: discipline,
                                                masteryLevel: masteryLevel,
                                                tier: .someday,
                                                impact: impact,
                                                cost: cost,
                                                status: .active)
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
        // 共有接続(6.3)。モデルごとに開くと database is locked を踏む
        return try AppDatabase.shared()
    }
}
