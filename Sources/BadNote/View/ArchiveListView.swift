import Foundation
import Observation
import SwiftUI
import SkipSQL

/// これまでに定着した課題(§7.4)。
@Observable public final class ArchiveListModel {
    public private(set) var issues: [Issue] = []
    public var errorText: String? = nil

    private var database: SQLContext? = nil

    public init() {
    }

    public func load() {
        do {
            issues = try IssueRepository(db: try context()).fetchArchived()
            errorText = nil
        } catch {
            errorText = "読み込みに失敗しました: \(error)"
        }
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

/// アーカイブ(§7.4 これまでに定着した課題)。
///
/// 定着した課題は一覧に出さないので、戻す導線はここだけ。
/// **達成の記録として気持ちよく見える画面にする** —— 件数で急かさない。
public struct ArchiveListView: View {
    @State private var model = ArchiveListModel()

    public init() {
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let errorText = model.errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                if model.issues.isEmpty {
                    Text("まだありません。課題を試合で出せるようになったら、ここに並びます", bundle: .module)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                ForEach(model.issues) { issue in
                    NavigationLink {
                        IssueDetailView(issueID: issue.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(issue.displayTitle)
                                .font(.body)
                            if let archivedAt = issue.archivedAt {
                                Text(archivedAt.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(.primary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()
        }
        .navigationTitle(Text("定着した課題", bundle: .module))
        .onAppear {
            model.load()
        }
    }
}
