import Foundation
import Observation
import SwiftUI
import SkipSQL

/// データの書き出し画面の状態(tasks.md 7.3)。
///
/// 画面を開いた時点の全データを JSON にして持つ。SQL は書かない。
/// 組み立ては `ExportRepository` に任せる。
@Observable public final class ExportModel {
    public private(set) var json: String? = nil
    public var errorText: String? = nil


    public init() {
    }

    public func load() {
        do {
            json = try ExportRepository(db: try context()).exportJSON()
            errorText = nil
        } catch {
            errorText = "書き出しの準備に失敗しました: \(error)"
        }
    }

    private func context() throws -> SQLContext {
        // 共有接続(6.3)。モデルごとに開くと database is locked を踏む
        return try AppDatabase.shared()
    }
}

/// データの書き出し(tasks.md 7.3)。
///
/// 全データを JSON 1 つにして**共有シートにテキストとして**送る。
/// ファイルにしないのは、SkipUI の `ShareLink` が Android ではテキスト共有
/// (`EXTRA_TEXT`)しかできないため。テキストならメール・メモ・Files など
/// 好きな置き場に残せて、それがそのままバックアップになる。
public struct ExportView: View {
    @State private var model = ExportModel()

    public init() {
    }

    public var body: some View {
        Form {
            if let errorText = model.errorText {
                Text(errorText)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
            Section {
                if let json = model.json {
                    ShareLink(item: json, subject: Text("BadNote のデータ", bundle: .module)) {
                        Label {
                            Text("共有シートで書き出す", bundle: .module)
                        } icon: {
                            Image("ios_share", bundle: .module)
                        }
                    }
                    .accessibilityIdentifier("export-share")
                }
            } footer: {
                Text("課題・練習ログ・大会・家トレなど、すべてのデータを 1 つの JSON にまとめて共有シートに送ります。メールやメモに残しておけば、それがバックアップになります", bundle: .module)
            }
            Section {
                Text("読み込み(復元)はまだありません。機種変更に備えて、書き出した JSON を保管しておいてください", bundle: .module)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(Text("データの書き出し", bundle: .module))
        .onAppear {
            model.load()
        }
    }
}
