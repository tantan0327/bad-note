import Foundation
import Observation
import SkipSQL

/// 練習ログ入力画面の状態(§7.2)。
///
/// SQL は書かない。永続化は `PracticeRepository` / `IssueRepository` に任せる。
@Observable public final class PracticeLogModel {

    /// 重点 1 件分の入力。`result` が nil なら未選択(そのまま保存できる)。
    public struct FocusInput: Identifiable, Hashable {
        public var issue: Issue
        public var result: FocusResult?

        public var id: Int64 {
            return issue.id
        }

        /// UI の主表示は完了形。未整理なら書いた原文をそのまま出す(§3.1)。
        public var title: String {
            if let doneForm = issue.doneForm, !doneForm.isEmpty {
                return doneForm
            }
            return issue.coachWords
        }
    }

    // MARK: - 入力(全項目任意)

    public var practiceDate = Date()
    /// 直接入力もできるので文字列で持つ。数値は `minutes` で取る。
    ///
    /// **0 は空文字で持つ。** 「0」が入っていると、直接入力するのにまず消す手間がかかる。
    public var minutesText = ""
    public var kind: PracticeKind? = nil
    public var focusInputs: [FocusInput] = []
    /// 手応えを選んだ回数。触覚フィードバックのトリガー(5.2)。読み込みでは増えない
    public private(set) var selectionCount = 0
    /// 「＋ もう 1 件追加」で確定した行
    public var addedCoachWords: [String] = []
    /// 入力中の 1 行
    public var coachWordsDraft = ""

    /// 本人に聞く 1 手(§3.2)。上げる / 戻す / 克服の 3 種を 1 本にまとめてある ——
    /// 判定を分けると「両方立つ」バグを自分で作ることになる。
    public struct OfferRow: Identifiable, Hashable {
        public var issue: Issue
        public var offer: MasteryOffer

        public var id: Int64 {
            return issue.id
        }
    }

    /// 提案は出ないが「今どこにいるか」を伝える課題(§7.2)。
    public struct StandingRow: Identifiable, Hashable {
        public var issue: Issue
        public var standing: MasteryStanding

        public var id: Int64 {
            return issue.id
        }
    }

    // MARK: - 表示状態

    public var errorText: String? = nil
    public var summaryText = ""
    public var isSaved = false
    /// 保存直後にだけ出す提案(§3.2)。承認 / 見送りで消える。
    public private(set) var offers: [OfferRow] = []
    /// 提案が出なかった課題の現在地(§7.2)。**提案が出た課題はここに出さない** ——
    /// 提案カードが課題名と現在地を既に語っている
    public private(set) var standings: [StandingRow] = []
    /// 未整理の件数(§5.3)。**保存直後にだけ見せる。**常設のバッジにはしない。
    public private(set) var unorganizedCount = 0
    /// この保存で越えた節目(時間)。保存直後にだけ祝う(§10.5。ふつうは空)。
    public private(set) var reachedMilestones: [Int] = []


    public init() {
    }

    public var minutes: Int {
        return Int(minutesText) ?? 0
    }

    // MARK: - 読み込み

    /// 今週の重点を読み込む。
    ///
    /// 過去日付を選んでも**現在の重点 3 つ**を出す(履歴は持たない割り切り。§7.2)。
    public func load() {
        do {
            let issues = IssueRepository(db: try context())
            let focus = try issues.fetch(tier: .focus, statuses: [.inbox, .active])
            var inputs: [FocusInput] = []
            for issue in focus {
                inputs.append(FocusInput(issue: issue, result: nil))
            }
            focusInputs = inputs
            errorText = nil
        } catch {
            errorText = "重点の読み込みに失敗しました: \(error)"
        }
    }

    // MARK: - 入力操作

    public func addMinutes(_ amount: Int) {
        minutesText = String(minutes + amount)
    }

    public func resetMinutes() {
        minutesText = ""
    }

    /// 同じ種類をもう一度押したら未選択に戻す。全項目任意なので選ばない状態を作れること。
    public func toggleKind(_ candidate: PracticeKind) {
        if kind == candidate {
            kind = nil
        } else {
            kind = candidate
        }
    }

    /// 同じ手応えをもう一度押したら未選択に戻す。
    public func toggleResult(_ candidate: FocusResult, for issueID: Int64) {
        for index in 0..<focusInputs.count {
            if focusInputs[index].id == issueID {
                if focusInputs[index].result == candidate {
                    focusInputs[index].result = nil
                } else {
                    focusInputs[index].result = candidate
                }
            }
        }
        selectionCount += 1
    }

    public func addCoachWords() {
        let trimmed = coachWordsDraft.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if trimmed.isEmpty {
            return
        }
        addedCoachWords.append(trimmed)
        coachWordsDraft = ""
    }

    public func removeCoachWords(at index: Int) {
        if index >= 0 && index < addedCoachWords.count {
            addedCoachWords.remove(at: index)
        }
    }

    /// 保存対象の原文。**入力中の 1 行も含める**(「＋」を押し忘れても失わない)。
    public func pendingCoachWords() -> [String] {
        var all: [String] = []
        all.append(contentsOf: addedCoachWords)
        let trimmed = coachWordsDraft.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if !trimmed.isEmpty {
            all.append(trimmed)
        }
        return all
    }

    // MARK: - 保存

    /// 練習ログと手応えを保存する。手応え未選択でも保存できる。
    ///
    /// 保存後は無言で閉じず、記録内容と今月の累計を出す(§7.2)。
    public func save() {
        do {
            let db = try context()
            let practices = PracticeRepository(db: db)
            let issues = IssueRepository(db: db)

            var focus: [FocusEntry] = []
            for input in focusInputs {
                // 未選択(nil)でも行は作る。累計時間の集計元になるため
                focus.append(FocusEntry(issueId: input.issue.id, result: input.result))
            }
            // 練習ログと「追加する課題」の原文は 1 つのトランザクションで保存する(6.3)。
            // 片方だけ残ると、§7.2 の保存後表示が嘘になる
            let practice = try db.transaction {
                let created = try practices.createInCurrentTransaction(practiceDate: practiceDate,
                                                                       minutes: minutes,
                                                                       kind: kind,
                                                                       focus: focus)
                // ここで書いた 1 行は未整理の課題として登録する(ここでは整理させない)
                for words in pendingCoachWords() {
                    _ = try issues.create(coachWords: words)
                }
                return created
            }

            let month = MonthRange.containing(practice.practiceDate)
            // 家トレも合算した累計(§10.3)
            let stats = StatsRepository(db: db)
            let monthTotal = try stats.totalMinutes(from: month.start, to: month.end)
            summaryText = PracticeLogModel.summary(recordedMinutes: practice.minutes, monthTotalMinutes: monthTotal)
            // この保存で節目を越えたら祝う(§10.5)。越えた瞬間はここでしか分からない
            let lifetime = try stats.lifetimeMinutes()
            reachedMilestones = Milestone.crossedHours(fromMinutes: lifetime - practice.minutes,
                                                       toMinutes: lifetime)
            try collectStandings(practices: practices, issues: issues)
            unorganizedCount = try issues.fetch(statuses: [.inbox]).count
            errorText = nil
            isSaved = true
        } catch {
            errorText = "保存に失敗しました: \(error)"
        }
    }

    /// 今回**手応えを付けた**課題の現在地を集める(§7.2)。
    ///
    /// **手応えを選んだ課題だけを見る。** それまで重点 3 件を無条件に回していたので、
    /// 1 つも選ばずに保存しても提案が湧いていた。提案は「いま押したことの結果」であるべき。
    ///
    /// 履歴は `fetchFocusResultsSinceLevelChange`(**いまの段になってから**)を使う。
    /// 全履歴を渡すと、上げた直後に同じ履歴でもう一度提案が出る。
    private func collectStandings(practices: PracticeRepository, issues: IssueRepository) throws {
        var collectedOffers: [OfferRow] = []
        var collectedStandings: [StandingRow] = []
        for input in focusInputs {
            if input.result == nil {
                continue
            }
            guard let issue = try issues.fetch(id: input.issue.id) else {
                continue
            }
            let history = try practices.fetchFocusResultsSinceLevelChange(issueId: issue.id)
            let standing = MasteryStanding.of(recentResults: history, issue: issue)
            if let offer = standing.offer {
                collectedOffers.append(OfferRow(issue: issue, offer: offer))
            } else {
                collectedStandings.append(StandingRow(issue: issue, standing: standing))
            }
        }
        offers = collectedOffers
        standings = collectedStandings
    }

    /// 提案を受け入れる(上げる / 戻す)。**克服はここを通らない** —— あちらは扉であって問いではない。
    public func accept(_ row: OfferRow) {
        do {
            var issue = row.issue
            issue.masteryLevel = row.offer.level
            // 断った記録の消去は `IssueRepository.update` が行う(経路が増えても漏れない)
            _ = try IssueRepository(db: try context()).update(issue)
            removeOffer(row)
            errorText = nil
        } catch {
            errorText = "レベルの更新に失敗しました: \(error)"
        }
    }

    /// 今はしない。同じ段では二度と聞かない(§3.2 1 度だけ提案する)。
    ///
    /// **上げると戻すで列を分けてある** —— 上げるのを断ったことが、
    /// 戻す提案まで黙らせるのは誤り。
    public func decline(_ row: OfferRow) {
        do {
            var issue = row.issue
            if row.offer.kind == MasteryOfferKind.levelUp {
                issue.levelUpDeclinedLevel = issue.masteryLevel.rawValue
            } else {
                issue.stepDownDeclinedLevel = issue.masteryLevel.rawValue
            }
            _ = try IssueRepository(db: try context()).update(issue)
            removeOffer(row)
            errorText = nil
        } catch {
            errorText = "更新に失敗しました: \(error)"
        }
    }

    private func removeOffer(_ row: OfferRow) {
        var remaining: [OfferRow] = []
        for existing in offers {
            if existing.id != row.id {
                remaining.append(existing)
            }
        }
        offers = remaining
    }

    /// 「90 分を記録しました / 今月の累計 14 時間」(§7.2)。
    static func summary(recordedMinutes: Int, monthTotalMinutes: Int) -> String {
        let total = monthTotalMinutes >= 60 ? "\(monthTotalMinutes / 60) 時間" : "\(monthTotalMinutes) 分"
        return "\(recordedMinutes) 分を記録しました\n今月の累計 \(total)"
    }

    private func context() throws -> SQLContext {
        // 共有接続(6.3)。モデルごとに開くと database is locked を踏む
        return try AppDatabase.shared()
    }
}
