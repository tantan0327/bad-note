import Foundation
import Observation
import SwiftUI
import SkipSQL

/// まとめて追加の状態(§5.2)。
///
/// **入るデータはあくまで個別の日付。** 曜日は日付を作るための入力でしかなく、
/// 保存されない。だから登録後は一覧から 1 日ずつ消せる(休みの日だけ外せる)。
@Observable public final class PracticePlanBulkAddModel {

    /// 選んだ曜日(0 = 日曜)
    public private(set) var weekdays: [Int] = []
    public var from = Date()
    public var through = Date()
    /// 終了日の既定をどこから取ったか。画面に理由を出すために持つ
    public private(set) var throughSource: String? = nil
    public var errorText: String? = nil

    public init() {
    }

    public func load(now: Date = Date()) {
        let today = Calendar.current.startOfDay(for: now)
        from = today
        do {
            let competitions = CompetitionRepository(db: try AppDatabase.shared())
            if let target = try nearestEvent(competitions: competitions, today: today) {
                // 大会の前日まで。大会当日は数えない規則と揃える(§5.2)
                through = Calendar.current.date(byAdding: Calendar.Component.day, value: -1, to: Calendar.current.startOfDay(for: target.eventDate)) ?? today
                throughSource = target.name
            } else {
                through = Calendar.current.date(byAdding: Calendar.Component.day, value: 28, to: today) ?? today
                throughSource = nil
            }
            errorText = nil
        } catch {
            through = Calendar.current.date(byAdding: Calendar.Component.day, value: 28, to: today) ?? today
            errorText = "大会の読み込みに失敗しました: \(error)"
        }
    }

    /// 目標大会があればそれ、無ければ手前の大会。どちらも無ければ nil。
    private func nearestEvent(competitions: CompetitionRepository, today: Date) throws -> Competition? {
        var candidates: [Competition] = []
        for discipline in [Discipline.singles, Discipline.doubles] {
            if let target = try competitions.fetchTarget(discipline: discipline) {
                candidates.append(target)
            }
        }
        if candidates.isEmpty {
            candidates = try competitions.fetchUpcoming(asOf: today)
        }
        var nearest: Competition? = nil
        for candidate in candidates {
            if candidate.eventDate <= today {
                continue
            }
            if let current = nearest {
                if candidate.eventDate < current.eventDate {
                    nearest = candidate
                }
            } else {
                nearest = candidate
            }
        }
        return nearest
    }

    public func isSelected(_ weekday: Int) -> Bool {
        for selected in weekdays {
            if selected == weekday {
                return true
            }
        }
        return false
    }

    public func toggle(_ weekday: Int) {
        var updated: [Int] = []
        var removed = false
        for selected in weekdays {
            if selected == weekday {
                removed = true
            } else {
                updated.append(selected)
            }
        }
        if !removed {
            updated.append(weekday)
        }
        weekdays = updated
    }

    /// 追加される日付。**画面のプレビューと保存で同じものを使う** ——
    /// 見えている数と書き込む数を食い違わせない。
    public var generated: [Date] {
        return PracticePlan.dates(weekdays: weekdays, from: from, through: through)
    }

    public func add() {
        do {
            try PracticePlanRepository(db: try AppDatabase.shared()).addAll(generated)
            errorText = nil
        } catch {
            errorText = "保存に失敗しました: \(error)"
        }
    }
}

/// 練習予定日をまとめて追加する(§5.2)。
///
/// 曜日と期間を選ぶと**個別の日付が生成されて登録される**。
/// 曜日そのものは保存しないので、登録後は一覧から 1 日ずつ消せる。
public struct PracticePlanBulkAddView: View {
    @State private var model = PracticePlanBulkAddModel()
    @Environment(\.dismiss) private var dismiss

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
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { weekday in
                        weekdayButton(weekday)
                    }
                }
            } header: {
                Text("曜日", bundle: .module)
            }

            Section {
                DatePicker(selection: $model.from, displayedComponents: .date) {
                    Text("開始", bundle: .module)
                        .font(.footnote)
                }
                .accessibilityIdentifier("practice-plan-bulk-from")
                DatePicker(selection: $model.through, displayedComponents: .date) {
                    Text("終了", bundle: .module)
                        .font(.footnote)
                }
                .accessibilityIdentifier("practice-plan-bulk-through")
            } header: {
                Text("期間", bundle: .module)
            } footer: {
                if let name = model.throughSource {
                    Text(verbatim: "「\(name)」の前日までを既定にしています")
                        .font(.caption)
                }
            }

            Section {
                Text(verbatim: "\(model.generated.count)日ぶんを追加します")
                    .font(.footnote)
                Text("すでに登録されている日は増えません", bundle: .module)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    model.add()
                    dismiss()
                } label: {
                    Text("追加する", bundle: .module)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.generated.isEmpty)
                .accessibilityIdentifier("practice-plan-bulk-add")
            }
        }
        .navigationTitle(Text("まとめて追加", bundle: .module))
        #if os(iOS) || os(Android)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            model.load()
        }
    }

    /// 選択中は塗り、未選択は枠だけ(通知設定にあった曜日ボタンをここへ移した)。
    @ViewBuilder private func weekdayButton(_ weekday: Int) -> some View {
        if model.isSelected(weekday) {
            Button {
                model.toggle(weekday)
            } label: {
                Text(verbatim: WeekdayName.of(weekday)).frame(minWidth: 28)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("practice-plan-weekday-\(weekday)")
        } else {
            Button {
                model.toggle(weekday)
            } label: {
                Text(verbatim: WeekdayName.of(weekday)).frame(minWidth: 28)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("practice-plan-weekday-\(weekday)")
        }
    }
}
