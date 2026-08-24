import Foundation
import Observation
import SwiftUI
import SkipSQL

/// 週次の組み替えモードの状態(§7.4)。
///
/// 重点 3 枠に対してタップで選ぶ専用モード。層の移動はすべて `FocusBoard` に任せる。
@Observable public final class FocusReshuffleModel {

    public private(set) var focus: [Issue] = []
    /// 重点に入れられる候補(次にやる / いつか)
    public private(set) var candidates: [Issue] = []
    /// 3 枠が埋まっているときの入れ替え候補
    public private(set) var swapCandidates: [Issue] = []
    /// 層を動かした回数。触覚フィードバックのトリガー(5.2)。読み込みでは増えない
    public private(set) var moveCount = 0
    public var isShowingSwap = false
    public var errorText: String? = nil

    private var pendingPromotion: Issue? = nil
    private var database: SQLContext? = nil

    public init() {
    }

    public var capacity: Int {
        return FocusBoard.focusCapacity
    }

    /// 空いている枠の数。
    public var remainingSlots: Int {
        let remaining = FocusBoard.focusCapacity - focus.count
        return remaining > 0 ? remaining : 0
    }

    public func load() {
        do {
            let issues = IssueRepository(db: try context())
            focus = try issues.fetch(tier: .focus, statuses: [.active])
            var pool: [Issue] = []
            pool.append(contentsOf: try issues.fetch(tier: .next, statuses: [.active]))
            pool.append(contentsOf: try issues.fetch(tier: .someday, statuses: [.active]))
            candidates = pool
            errorText = nil
        } catch {
            errorText = "課題の読み込みに失敗しました: \(error)"
        }
    }

    /// 候補をタップして重点に入れる。埋まっていれば入れ替えを聞く。
    public func add(_ issue: Issue) {
        let result = FocusBoard.move(issue, to: .focus, at: Int.max, in: allIssues())
        if let candidates = result.swapCandidates {
            pendingPromotion = issue
            swapCandidates = candidates
            isShowingSwap = true
            return
        }
        if let updated = result.updatedIssues {
            apply(updated)
        }
    }

    /// 重点をタップして外す。押した 1 つが `next` に降りる。
    public func remove(_ issue: Issue) {
        let result = FocusBoard.move(issue, to: .next, at: Int.max, in: allIssues())
        if let updated = result.updatedIssues {
            apply(updated)
        }
    }

    public func confirmSwap(with demoting: Issue) {
        guard let promoting = pendingPromotion else {
            cancelSwap()
            return
        }
        apply(FocusBoard.swap(promoting: promoting, demoting: demoting, in: allIssues()))
        cancelSwap()
    }

    public func cancelSwap() {
        pendingPromotion = nil
        swapCandidates = []
        isShowingSwap = false
    }

    private func allIssues() -> [Issue] {
        var all: [Issue] = []
        all.append(contentsOf: focus)
        all.append(contentsOf: candidates)
        return all
    }

    private func apply(_ updated: [Issue]) {
        do {
            let issues = IssueRepository(db: try context())
            for issue in updated {
                _ = try issues.update(issue)
            }
            moveCount += 1
            errorText = nil
        } catch {
            errorText = "保存に失敗しました: \(error)"
        }
        load()
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

/// 週次の組み替えモード(§7.4)。
///
/// 重点 3 枠に対してタップで選ぶ。ドラッグもスワイプも使わず、
/// 「今週は何をやるか」を決めることだけに集中する画面。
public struct FocusReshuffleView: View {
    @State private var model = FocusReshuffleModel()

    public init() {
    }

    public var body: some View {
        List {
            if let errorText = model.errorText {
                Text(errorText)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Section {
                if model.focus.isEmpty {
                    Text("まだ選んでいません", bundle: .module)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                ForEach(model.focus) { issue in
                    Button {
                        // 層の移動はゆっくり(5.1)
                        withAnimation(Motion.move) {
                            model.remove(issue)
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(issue.displayTitle)
                                    .font(.body)
                                MasteryIndicator(level: issue.masteryLevel)
                            }
                            Spacer()
                            // 押せる導線はリンク色(2.3。灰色だと押せると分からない)
                            Text("外す", bundle: .module)
                                .font(.footnote)
                                .foregroundStyle(Palette.accent)
                        }
                        .foregroundStyle(.primary)
                    }
                }
            } header: {
                HStack {
                    Text("今週の重点", bundle: .module)
                    Spacer()
                    Text(verbatim: "\(model.focus.count)/\(model.capacity)")
                }
            }

            Section {
                if model.candidates.isEmpty {
                    Text("候補がありません", bundle: .module)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                ForEach(model.candidates) { issue in
                    Button {
                        withAnimation(Motion.move) {
                            model.add(issue)
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(issue.displayTitle)
                                    .font(.body)
                                MasteryIndicator(level: issue.masteryLevel)
                            }
                            Spacer()
                            // 押せる導線はリンク色(2.3)
                            Text("選ぶ", bundle: .module)
                                .font(.footnote)
                                .foregroundStyle(Palette.accent)
                        }
                        .foregroundStyle(.primary)
                    }
                }
            } header: {
                Text("候補", bundle: .module)
            }
        }
        .navigationTitle(Text("今週の重点を組み替える", bundle: .module))
        // 5.2 選ぶ / 外すも層の移動。触覚を添える
        .sensoryFeedback(SensoryFeedback.impact, trigger: model.moveCount)
        .confirmationDialog(Text("どれと入れ替えますか?", bundle: .module),
                            isPresented: $model.isShowingSwap,
                            titleVisibility: .visible) {
            ForEach(model.swapCandidates) { candidate in
                Button {
                    model.confirmSwap(with: candidate)
                } label: {
                    Text(candidate.displayTitle)
                }
            }
            Button(role: .cancel) {
                model.cancelSwap()
            } label: {
                Text("やめる", bundle: .module)
            }
        }
        .onAppear {
            model.load()
        }
    }
}
