import Foundation
import Observation
import SwiftUI
import SkipSQL

/// 練習予定日の状態(§5.2)。
@Observable public final class PracticePlanModel {

    /// これからの予定日(古い順)。過ぎた日は出さない。
    public private(set) var days: [PracticePlanDay] = []
    /// 追加する日。既定は今日
    public var pickedDate = Date()
    public var errorText: String? = nil

    public init() {
    }

    public func load(now: Date = Date()) {
        do {
            let today = Calendar.current.startOfDay(for: now)
            days = try repository().fetchUpcoming(asOf: today)
            errorText = nil
        } catch {
            errorText = "練習予定日の読み込みに失敗しました: \(error)"
        }
    }

    public func addPickedDate() {
        do {
            try repository().add(pickedDate)
            errorText = nil
        } catch {
            errorText = "保存に失敗しました: \(error)"
        }
        load()
    }

    public func remove(_ day: PracticePlanDay) {
        do {
            try repository().remove(day)
            errorText = nil
        } catch {
            errorText = "削除に失敗しました: \(error)"
        }
        load()
    }

    private func repository() throws -> PracticePlanRepository {
        // 共有接続。モデルごとに開くと database is locked を踏む
        return PracticePlanRepository(db: try AppDatabase.shared())
    }
}

/// 練習予定日(§5.2)。設定から開く。
///
/// **ここに登録した日数が、そのまま大会までの「あと N回」になる。**
/// 以前は練習履歴から頻度を推定していたが、実際とずれた。
/// 練習前の通知(§8)もこの日にだけ出る。
public struct PracticePlanView: View {
    @State private var model = PracticePlanModel()

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
                DatePicker(selection: $model.pickedDate, displayedComponents: .date) {
                    Text("日付", bundle: .module)
                        .font(.footnote)
                }
                .accessibilityIdentifier("practice-plan-picker")
                Button {
                    withAnimation(Motion.move) {
                        model.addPickedDate()
                    }
                } label: {
                    Text("この日を追加", bundle: .module)
                        .font(.footnote)
                }
                .accessibilityIdentifier("practice-plan-add-day")
            } header: {
                Text("1 日ずつ追加", bundle: .module)
            }

            Section {
                if model.days.isEmpty {
                    // 空の状態は灰色 1 行で済ませない。次の 1 手を置く
                    EmptyStateView(message: Text("練習予定日はまだありません", bundle: .module)) {
                        NavigationLink {
                            PracticePlanBulkAddView()
                        } label: {
                            Text("まとめて追加する", bundle: .module)
                                .font(.footnote)
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("practice-plan-empty-bulk")
                    }
                }
                ForEach(model.days) { day in
                    // その日そのものが主役の場面なので曜日つき(デザインの決めごと)
                    Text(DateText.dayWithWeekday(day.date))
                        .font(.body)
                        .accessibilityIdentifier("practice-plan-row-\(day.day)")
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                withAnimation(Motion.move) {
                                    model.remove(day)
                                }
                            } label: {
                                Text("削除", bundle: .module)
                            }
                        }
                }
            } header: {
                HStack {
                    Text("これからの予定日", bundle: .module)
                    Spacer()
                    Text(verbatim: "\(model.days.count)日")
                }
            } footer: {
                // スワイプは画面から見えない操作なので言葉で常設する(§4.3 と同じ扱い)
                Text("行を左にスワイプすると削除できます。大会までの「あと何回」はこの日数で数えます",
                     bundle: .module)
                    .font(.caption)
            }
        }
        .navigationTitle(Text("練習予定日", bundle: .module))
        #if os(iOS) || os(Android)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    PracticePlanBulkAddView()
                } label: {
                    Text("まとめて追加", bundle: .module)
                }
                .accessibilityIdentifier("practice-plan-bulk")
            }
        }
        .onAppear {
            model.load()
        }
    }
}
