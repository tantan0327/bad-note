import Foundation
import Observation
import SwiftUI
import SkipSQL

/// 棚卸し画面の状態(2026-10-11)。
///
/// **「いつか」に溜まった課題を、放置が長い順に 1 件ずつ見直す。**
/// 出口は 3 つ —— 残す / 次にやるへ上げる / 見送る。
///
/// 1 件ずつなのは未整理の整理と同じ理由(一覧で眺めると手が止まる)。
/// 1 回の上限は `ReviewSchedule.sessionLimit`。終わらない棚卸しは二度とやられない。
///
/// SQL は書かない。永続化は `IssueRepository` / `AppMetaRepository` に任せる。
@Observable public final class IssueReviewModel {

    /// 開いた時点の対象。処理中に増減させない(足元が動くと迷子になる)。
    public private(set) var queue: [Issue] = []
    public private(set) var index = 0
    /// この棚卸しで見送った件数。
    public private(set) var shelvedCount = 0
    /// この棚卸しで次にやるへ上げた件数。
    public private(set) var promotedCount = 0

    public var errorText: String? = nil

    public init() {
    }

    /// 今見ている課題。すべて見終えたら nil。
    public var current: Issue? {
        if index < queue.count {
            return queue[index]
        }
        return nil
    }

    public var isFinished: Bool {
        return index >= queue.count
    }

    /// この課題を含む残り件数(未整理の整理と同じ出し方)。
    public var remainingCount: Int {
        let remaining = queue.count - index
        return remaining > 0 ? remaining : 0
    }

    /// 最後に触れた日。**判断材料として出す** —— アプリは解釈を足さない。
    public func lastTouched(_ issue: Issue) -> Date {
        return issue.lastFocusedAt ?? issue.createdAt
    }

    /// 一度も重点にしていないか。「放置」の中身が違うので言い分ける。
    public func hasNeverBeenFocused(_ issue: Issue) -> Bool {
        return issue.lastFocusedAt == nil
    }

    // MARK: - 読み込み

    public func load() {
        do {
            let issues = IssueRepository(db: try context())
            let someday = try issues.fetch(tier: .someday, statuses: [IssueStatus.active])
            queue = ReviewSchedule.queue(from: someday)
            index = 0
            shelvedCount = 0
            promotedCount = 0
            errorText = nil
        } catch {
            errorText = "棚卸しの読み込みに失敗しました: \(error)"
        }
    }

    // MARK: - 3 つの出口

    /// 残す。**何も書き換えない。**
    ///
    /// 翌月また出てくるが、それでよい —— 忘れているものを順に見せるのが目的で、
    /// 一度残したからといって隠すと棚卸しの意味が無くなる。
    public func keep() {
        advance()
    }

    /// 次にやるへ上げる。層の移動は `FocusBoard` に任せる。
    public func promote() {
        guard let issue = current else {
            return
        }
        do {
            let repository = IssueRepository(db: try context())
            let all = try repository.fetch(statuses: [IssueStatus.active])
            let result = FocusBoard.move(issue, to: Tier.next, at: Int.max, in: all)
            if let updated = result.updatedIssues {
                for changed in updated {
                    _ = try repository.update(changed)
                }
            }
            promotedCount += 1
            errorText = nil
            advance()
        } catch {
            errorText = "上げるのに失敗しました: \(error)"
        }
    }

    /// 見送る。**定着(`archived`)とは別の状態にする** ——
    /// 積み上げの「定着した課題」に混ぜると、外すたびに達成の数字が嘘になる。
    ///
    /// 消さずに残すので、設定の「見送った課題」からいつでも戻せる。
    public func shelve() {
        guard let issue = current else {
            return
        }
        do {
            var edited = issue
            edited.status = IssueStatus.shelved
            edited.archivedAt = Date()
            _ = try IssueRepository(db: try context()).update(edited)
            shelvedCount += 1
            errorText = nil
            advance()
        } catch {
            errorText = "見送るのに失敗しました: \(error)"
        }
    }

    // MARK: - 終わり方

    /// 最後まで見た、または「またにする」。**どちらも次は 30 日後。**
    ///
    /// 途中でやめた回も記録するのは、毎回開くたびに誘われないようにするため。
    public func markDone(now: Date = Date()) {
        do {
            try AppMetaRepository(db: try context()).setReviewLastDoneAt(now)
            errorText = nil
        } catch {
            errorText = "棚卸しの記録に失敗しました: \(error)"
        }
    }

    private func advance() {
        index += 1
    }

    private func context() throws -> SQLContext {
        // 共有接続(6.3)。モデルごとに開くと database is locked を踏む
        return try AppDatabase.shared()
    }
}

/// 棚卸し(2026-10-11)。
///
/// **月 1 回、「いつか」に溜まった課題を残すか見送るか決める場。**
/// 課題は入口が自由で出口が実績ゲート(克服は Lv.4 のみ)なので、
/// 定期的に外す機会が無いと減らない。
///
/// **アプリは解釈や警告を出さない。** 「古いから捨てましょう」とは言わず、
/// 最後に触れた日と習熟度を並べて、決めるのは本人に任せる。
public struct IssueReviewView: View {
    @State private var model = IssueReviewModel()
    @Environment(\.dismiss) private var dismiss

    public init() {
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let errorText = model.errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                if let issue = model.current {
                    remainingLabel
                    issueCard(issue)
                    actionSection
                } else {
                    finishedSection
                }
            }
            .padding()
        }
        .navigationTitle(Text("棚卸し", bundle: .module))
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    // 途中でやめても次は 30 日後。毎回開くたびに誘わない
                    model.markDone()
                    dismiss()
                } label: {
                    Text("またにする", bundle: .module)
                }
                .accessibilityIdentifier("review-postpone")
            }
        }
        .onAppear {
            if model.queue.isEmpty {
                model.load()
            }
        }
    }

    @ViewBuilder private var remainingLabel: some View {
        Text(verbatim: "残り \(model.remainingCount) 件")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    /// 判断の材料だけを並べる。**課題名 → 放置の長さ → 今の段**の順。
    @ViewBuilder private func issueCard(_ issue: Issue) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text(issue.displayTitle)
                    .font(.title2)
                // 言い換えを持っているときだけ原文を引く(持っていなければ上と同じ文になる)
                if issue.hasDoneForm {
                    Text(issue.coachWords)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    if model.hasNeverBeenFocused(issue) {
                        Text(verbatim: "一度も重点にしていません(\(DateText.day(issue.createdAt)) に登録)")
                    } else {
                        Text(verbatim: "最後に重点にしたのは \(DateText.day(model.lastTouched(issue)))")
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                MasteryIndicator(level: issue.masteryLevel)
            }
        }
    }

    /// 出口は 3 つ。**残すが既定の構え**(強いボタンは置かない) ——
    /// 捨てる側を押しやすくすると、アプリが減らすほうへ背中を押すことになる。
    @ViewBuilder private var actionSection: some View {
        VStack(spacing: 12) {
            Button {
                withAnimation(Motion.move) {
                    model.keep()
                }
            } label: {
                Text("残す", bundle: .module)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("review-keep")

            HStack(spacing: 12) {
                Button {
                    withAnimation(Motion.move) {
                        model.promote()
                    }
                } label: {
                    Text("次にやるへ", bundle: .module)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("review-promote")

                Button {
                    withAnimation(Motion.move) {
                        model.shelve()
                    }
                } label: {
                    Text("見送る", bundle: .module)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("review-shelve")
            }
            Text("見送った課題は設定から戻せます", bundle: .module)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    @ViewBuilder private var finishedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if model.queue.isEmpty {
                // 設定からはいつでも開けるので、対象が無いこともある
                Text("「いつか」に置いたままの課題はありません", bundle: .module)
                    .font(.headline)
            } else {
                Text("棚卸しが終わりました", bundle: .module)
                    .font(.headline)
                // 数字は「やった分」だけ出す。残っている件数は出さない(§5.3)
                if model.promotedCount > 0 {
                    Text(verbatim: "\(model.promotedCount) 件を次にやるへ上げました")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if model.shelvedCount > 0 {
                    Text(verbatim: "\(model.shelvedCount) 件を見送りました")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Button {
                model.markDone()
                dismiss()
            } label: {
                Text("閉じる", bundle: .module)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("review-done")
        }
    }
}
