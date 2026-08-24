import Foundation
import Observation
import SkipSQL

/// 課題詳細の状態(§7.3)。
///
/// 記録(累計時間 / 重点にした回数 / 再浮上回数)はすべて集計で求める。値は保持しない。
@Observable public final class IssueDetailModel {

    private let issueID: Int64

    public private(set) var issue: Issue? = nil
    public private(set) var tags: [Tag] = []
    /// 累計時間(分)。1 練習の時間は重点それぞれに満額計上される(§6)。
    public private(set) var totalMinutes = 0
    /// 重点にした回数(`focus_span` の件数)
    public private(set) var focusCount = 0
    /// 手応えの履歴。**古い順**(進み方をそのまま左から並べる)。nil は未入力。
    public private(set) var progress: [FocusResult?] = []

    public var errorText: String? = nil
    /// Lv.4 未満で「克服した」を押したときの理由(§7.3)
    public var overcomeRejection: String? = nil


    public init(issueID: Int64) {
        self.issueID = issueID
    }

    /// 1 つ上のレベル。Lv.4 なら nil(上げ先が無い)。
    public var nextLevel: MasteryLevel? {
        guard let issue = issue else {
            return nil
        }
        return MasteryLevel(rawValue: issue.masteryLevel.rawValue + 1)
    }

    public var isArchived: Bool {
        return issue?.status == IssueStatus.archived
    }

    public func load() {
        do {
            let db = try context()
            let issues = IssueRepository(db: db)
            guard let loaded = try issues.fetch(id: issueID) else {
                errorText = "課題が見つかりません"
                return
            }
            issue = loaded
            tags = try TagRepository(db: db).fetchTags(issueId: issueID)
            let practices = PracticeRepository(db: db)
            totalMinutes = try practices.totalMinutes(issueId: issueID)
            focusCount = try issues.focusSpanCount(issueId: issueID)
            // 新しい順で返るので、時系列に並べ直す
            progress = IssueDetailModel.oldestFirst(try practices.fetchFocusResults(issueId: issueID))
            errorText = nil
        } catch {
            errorText = "読み込みに失敗しました: \(error)"
        }
    }

    // MARK: - 操作

    /// 習熟度を 1 つ上げる。履歴は `IssueRepository` が自動で残す。
    public func raiseLevel() {
        guard let current = issue, let next = nextLevel else {
            return
        }
        do {
            var edited = current
            edited.masteryLevel = next
            // 上げたので、提案を断った記録は用済み
            edited.levelUpDeclinedLevel = nil
            _ = try IssueRepository(db: try context()).update(edited)
            load()
        } catch {
            errorText = "レベルの更新に失敗しました: \(error)"
        }
    }

    /// レベルを 1 つ下げる。日常操作ではないので「⋯」の中に置く(§3.2)。
    public func lowerLevel() {
        guard let current = issue else {
            return
        }
        if current.masteryLevel == MasteryLevel.solo {
            return
        }
        do {
            var edited = current
            edited.masteryLevel = current.masteryLevel.oneStepDown
            _ = try IssueRepository(db: try context()).update(edited)
            load()
        } catch {
            errorText = "レベルの更新に失敗しました: \(error)"
        }
    }

    /// 克服した(定着確認へ)。**Lv.4 のときだけ通す**(§7.3)。
    public func overcome() {
        guard let current = issue else {
            return
        }
        if !current.masteryLevel.canOvercome {
            overcomeRejection = "まだ試合で出せていません"
            return
        }
        do {
            var edited = current
            edited.status = .archived
            edited.archivedAt = Date()
            _ = try IssueRepository(db: try context()).update(edited)
            overcomeRejection = nil
            load()
        } catch {
            errorText = "更新に失敗しました: \(error)"
        }
    }

    /// 再浮上させる。**レベルは前回の 1 つ下から再開する**(§7.3 ゼロに戻さない)。
    public func resurface() {
        guard let current = issue else {
            return
        }
        do {
            var edited = current
            edited.status = .active
            edited.archivedAt = nil
            edited.masteryLevel = current.masteryLevel.oneStepDown
            edited.resurfaceCount += 1
            _ = try IssueRepository(db: try context()).update(edited)
            load()
        } catch {
            errorText = "更新に失敗しました: \(error)"
        }
    }

    // MARK: - 内部

    private static func oldestFirst(_ results: [FocusResult?]) -> [FocusResult?] {
        var reversed: [FocusResult?] = []
        for index in 0..<results.count {
            reversed.append(results[results.count - 1 - index])
        }
        return reversed
    }

    private func context() throws -> SQLContext {
        // 共有接続(6.3)。モデルごとに開くと database is locked を踏む
        return try AppDatabase.shared()
    }
}
