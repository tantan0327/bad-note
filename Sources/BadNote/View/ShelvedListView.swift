import Foundation
import Observation
import SwiftUI
import SkipSQL

/// 見送った課題(2026-10-11)。
@Observable public final class ShelvedListModel {
    public private(set) var issues: [Issue] = []
    public var errorText: String? = nil

    public init() {
    }

    public func load() {
        do {
            issues = try IssueRepository(db: try context()).fetchShelved()
            errorText = nil
        } catch {
            errorText = "読み込みに失敗しました: \(error)"
        }
    }

    /// 一覧に戻す。**段は下げない。**
    ///
    /// 定着からの再浮上(`IssueDetailModel.resurface`)は 1 つ下の段から
    /// 再開するが、見送りは**何も達成していない** —— 置いておいただけなので、
    /// 外したときの段のまま「いつか」へ戻す。
    public func restore(_ issue: Issue) {
        do {
            var edited = issue
            edited.status = IssueStatus.active
            edited.archivedAt = nil
            _ = try IssueRepository(db: try context()).update(edited)
            errorText = nil
            load()
        } catch {
            errorText = "戻すのに失敗しました: \(error)"
        }
    }

    private func context() throws -> SQLContext {
        // 共有接続(6.3)。モデルごとに開くと database is locked を踏む
        return try AppDatabase.shared()
    }
}

/// 見送った課題(2026-10-11)。
///
/// 棚卸し(`IssueReviewView`)で外した課題の置き場。**片道にしない**ための画面。
/// 定着した課題とは別にしてある —— 見送りは達成ではないので、積み上げに混ぜない。
public struct ShelvedListView: View {
    @State private var model = ShelvedListModel()

    public init() {
    }

    public var body: some View {
        // 同じ形の行を選ぶだけの画面なので List(区切り線の決めごと)
        List {
            if let errorText = model.errorText {
                Text(errorText)
                    .font(.footnote)
                    .foregroundStyle(Palette.error)
            }
            if model.issues.isEmpty {
                Text("まだありません。棚卸しで見送った課題がここに並びます", bundle: .module)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(model.issues) { issue in
                VStack(alignment: .leading, spacing: 4) {
                    Text(issue.displayTitle)
                        .font(.body)
                    if let archivedAt = issue.archivedAt {
                        Text(DateText.day(archivedAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("shelved-row-\(issue.id)")
                // 戻すのはこの画面にしか無い操作なので、スワイプで完結させる
                .swipeActions(edge: .trailing) {
                    Button {
                        withAnimation(Motion.move) {
                            model.restore(issue)
                        }
                    } label: {
                        Text("戻す", bundle: .module)
                    }
                }
            }
        }
        .navigationTitle(Text("見送った課題", bundle: .module))
        .onAppear {
            model.load()
        }
    }
}
