import Foundation
import Observation
import SwiftUI
import SkipSQL

/// stale 閾値の設定の状態(§4.2 / tasks.md 2.6)。変更のたびに保存する。
@Observable public final class StaleSettingsModel {
    public private(set) var days = StaleThresholds.standard.days
    public private(set) var practiceCount = StaleThresholds.standard.practiceCount
    public var errorText: String? = nil

    private var database: SQLContext? = nil

    public init() {
    }

    public func load() {
        do {
            let thresholds = try AppMetaRepository(db: try context()).staleThresholds()
            days = thresholds.days
            practiceCount = thresholds.practiceCount
            errorText = nil
        } catch {
            errorText = "読み込みに失敗しました: \(error)"
        }
    }

    /// 週 1 回の評価(§4.3)より短くしても意味が無いので最短 7 日。上限は 90 日。
    public func updateDays(_ value: Int) {
        days = min(max(value, 7), 90)
        save()
    }

    public func updatePracticeCount(_ value: Int) {
        practiceCount = min(max(value, 1), 30)
        save()
    }

    /// Stepper のラベル。型を String にしておく(LocalizedStringKey の解釈をさせない)。
    public var daysText: String {
        return "\(days) 日"
    }

    public var practiceCountText: String {
        return "\(practiceCount) 回"
    }

    private func save() {
        do {
            try AppMetaRepository(db: try context()).setStaleThresholds(StaleThresholds(days: days, practiceCount: practiceCount))
            errorText = nil
        } catch {
            errorText = "保存に失敗しました: \(error)"
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

/// stale 閾値の設定(§4.2 / tasks.md 2.6)。
///
/// 「忘れかけ」と見なす基準を本人が調整できるようにする。
/// 次の週次評価(§4.3)から新しい閾値で判定される。
public struct StaleSettingsView: View {
    @State private var model = StaleSettingsModel()

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
                // Stepper(value:label:) は Kotlin でオーバーロード解決できない(開発メモ)。
                // Binding を使わない onIncrement / onDecrement 形にする
                HStack {
                    Text("触れていない日数", bundle: .module)
                    Spacer()
                    Stepper(model.daysText,
                            onIncrement: { model.updateDays(model.days + 1) },
                            onDecrement: { model.updateDays(model.days - 1) })
                }
                .accessibilityIdentifier("stale-days-stepper")
            } footer: {
                Text("一度も重点に入らないまま、または更新が無いまま、この日数が過ぎた課題を「しばらく触れていない」と数えます", bundle: .module)
            }
            Section {
                HStack {
                    Text("外れてからの練習回数", bundle: .module)
                    Spacer()
                    Stepper(model.practiceCountText,
                            onIncrement: { model.updatePracticeCount(model.practiceCount + 1) },
                            onDecrement: { model.updatePracticeCount(model.practiceCount - 1) })
                }
                .accessibilityIdentifier("stale-count-stepper")
            } footer: {
                Text("重点から外れたあと、この回数の練習に触れなかった課題も数えます", bundle: .module)
            }
            Section {
                Text("知らせるのは週 1 回、組み替えの曜日だけです。次の評価から新しい基準で判定します", bundle: .module)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(Text("しばらく触れていない課題", bundle: .module))
        .onAppear {
            model.load()
        }
    }
}
