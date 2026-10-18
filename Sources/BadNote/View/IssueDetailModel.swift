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
    /// 今どこにいるか(§3.2)。**提案の判定と同じ値から作る**ので、
    /// 「進んでいます」と出ているのに提案が出ない、が起きない
    public private(set) var standing: MasteryStanding? = nil

    public var errorText: String? = nil
    /// Lv.4 未満で「克服した」を押したときの理由(§7.3)
    public var overcomeRejection: String? = nil

    /// 重点が埋まっているときに保留している昇格先(§7.4)。
    private var pendingPromotion: Issue? = nil
    /// 「どれと入れ替えますか?」の候補(現在の重点 3 件)
    public private(set) var swapCandidates: [Issue] = []
    public var isShowingSwap = false


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
            // 現在地は**いまの段になってから**の手応えで決める(全履歴だと段を上げても変わらない)
            standing = MasteryStanding.of(recentResults: try practices.fetchFocusResultsSinceLevelChange(issueId: issueID),
                                          issue: loaded)
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
            // 断った記録の消去は `IssueRepository.update` が行う(経路が増えても漏れない)
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

    // MARK: - 優先度の層(§3.3 / §7.4)

    /// 層を変える。**一覧と同じ `FocusBoard` を通す**(2026-10-18)。
    ///
    /// それまで層は一覧の長押しドラッグとスワイプ、ホームの 3 択からしか変えられず、
    /// 詳細では「種目や優先度を見る」に**読むだけ**で出ていた。
    /// 1 件を見て決める画面なのに、そこで決められなかった。
    ///
    /// **素通しで `tier` を書き換えない。** 重点は 3 枠なので、埋まっていれば
    /// `FocusBoard.move` が `.needsSwap` を返す。編集画面にピッカーを足す案を
    /// 採らなかったのはこのため —— あの画面は保存までこの判定を通せない。
    public func move(to tier: Tier) {
        guard let current = issue else {
            return
        }
        if current.tier == tier {
            return
        }
        do {
            let board = try IssueRepository(db: try context()).fetch(statuses: [IssueStatus.inbox, IssueStatus.active])
            // 末尾に置く。範囲外の位置は FocusBoard 側で丸められる
            let result = FocusBoard.move(current, to: tier, at: Int.max, in: board)
            if let candidates = result.swapCandidates {
                pendingPromotion = current
                swapCandidates = candidates
                isShowingSwap = true
                return
            }
            if let updated = result.updatedIssues {
                try apply(updated)
            }
            load()
        } catch {
            errorText = "優先度の変更に失敗しました: \(error)"
        }
    }

    /// 「どれと入れ替えますか?」で選ばれた 1 件を next に降ろし、この課題を重点に入れる。
    public func confirmSwap(with demoting: Issue) {
        guard let promoting = pendingPromotion else {
            cancelSwap()
            return
        }
        do {
            let board = try IssueRepository(db: try context()).fetch(statuses: [IssueStatus.inbox, IssueStatus.active])
            try apply(FocusBoard.swap(promoting: promoting, demoting: demoting, in: board))
            cancelSwap()
            load()
        } catch {
            errorText = "入れ替えに失敗しました: \(error)"
        }
    }

    public func cancelSwap() {
        pendingPromotion = nil
        swapCandidates = []
        isShowingSwap = false
    }

    /// **未整理のまま重点に上げたら `active` にする。**
    /// ホームの 3 択と同じ —— 重点にする判断そのものが整理なので、
    /// `inbox` のままだと一覧にもホームにも出ず行き場を失う。
    /// 再浮上の回数はここでは数えない(ホームの 3 択だけが再浮上)。
    private func apply(_ updated: [Issue]) throws {
        let issues = IssueRepository(db: try context())
        for issue in updated {
            var target = issue
            if target.tier == Tier.focus && target.status == IssueStatus.inbox {
                target.status = IssueStatus.active
            }
            _ = try issues.update(target)
        }
        errorText = nil
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
