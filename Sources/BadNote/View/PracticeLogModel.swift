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

        /// UI の主表示は完了形。未整理ならコーチの言葉をそのまま出す(§3.1)。
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
    public var minutesText = "0"
    public var kind: PracticeKind? = nil
    public var focusInputs: [FocusInput] = []
    /// 「＋ もう 1 件追加」で確定した行
    public var addedCoachWords: [String] = []
    /// 入力中の 1 行
    public var coachWordsDraft = ""

    // MARK: - 表示状態

    public var errorText: String? = nil
    public var isShowingSummary = false
    public var summaryText = ""
    public var isSaved = false

    private var database: SQLContext? = nil

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
        minutesText = "0"
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

    /// 保存対象のコーチの言葉。**入力中の 1 行も含める**(「＋」を押し忘れても失わない)。
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
            let practice = try practices.create(practiceDate: practiceDate,
                                                minutes: minutes,
                                                kind: kind,
                                                focus: focus)

            // 今日言われたことは未整理の課題として登録する(ここでは整理させない)
            for words in pendingCoachWords() {
                _ = try issues.create(coachWords: words)
            }

            let month = MonthRange.containing(practice.practiceDate)
            let monthTotal = try practices.totalMinutes(from: month.start, to: month.end)
            summaryText = PracticeLogModel.summary(recordedMinutes: practice.minutes, monthTotalMinutes: monthTotal)
            errorText = nil
            isSaved = true
            isShowingSummary = true
        } catch {
            errorText = "保存に失敗しました: \(error)"
        }
    }

    /// 「90 分を記録しました / 今月の累計 14 時間」(§7.2)。
    static func summary(recordedMinutes: Int, monthTotalMinutes: Int) -> String {
        let total = monthTotalMinutes >= 60 ? "\(monthTotalMinutes / 60) 時間" : "\(monthTotalMinutes) 分"
        return "\(recordedMinutes) 分を記録しました\n今月の累計 \(total)"
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
