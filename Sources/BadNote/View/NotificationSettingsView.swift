import Foundation
import Observation
import SwiftUI
import SkipSQL

/// 通知設定の状態(§8)。
@Observable public final class NotificationSettingsModel {

    public var isEnabled = false
    public var practiceWeekdays: [Int] = []
    public var practiceHour = 18
    public var eveningHour = 20
    public var reshuffleWeekday = 0
    public var errorText: String? = nil

    private var database: SQLContext? = nil

    public init() {
    }

    public func load() {
        do {
            let settings = try AppMetaRepository(db: try context()).notificationSettings()
            isEnabled = settings.isEnabled
            practiceWeekdays = settings.practiceWeekdays
            practiceHour = settings.practiceHour
            eveningHour = settings.eveningHour
            reshuffleWeekday = settings.reshuffleWeekday
            errorText = nil
        } catch {
            errorText = "読み込みに失敗しました: \(error)"
        }
    }

    public func isPracticeDay(_ weekday: Int) -> Bool {
        for value in practiceWeekdays {
            if value == weekday {
                return true
            }
        }
        return false
    }

    public func togglePracticeDay(_ weekday: Int) {
        var updated: [Int] = []
        var removed = false
        for value in practiceWeekdays {
            if value == weekday {
                removed = true
            } else {
                updated.append(value)
            }
        }
        if !removed {
            updated.append(weekday)
        }
        practiceWeekdays = updated
        save()
    }

    public func updateEnabled(_ enabled: Bool) {
        isEnabled = enabled
        save()
    }

    public func updatePracticeHour(_ hour: Int) {
        practiceHour = hour
        save()
    }

    public func updateEveningHour(_ hour: Int) {
        eveningHour = hour
        save()
    }

    /// 変更のたびに保存して予定を入れ直す。**設定と実際の通知をずらさない。**
    public func save() {
        do {
            let db = try context()
            try AppMetaRepository(db: db).setNotificationSettings(NotificationSettings(isEnabled: isEnabled,
                                                                                       practiceWeekdays: practiceWeekdays,
                                                                                       practiceHour: practiceHour,
                                                                                       eveningHour: eveningHour,
                                                                                       reshuffleWeekday: reshuffleWeekday))
            // 予定の組み立ては同じ接続で。登録だけを非同期に投げる
            let planned = try NotificationService(db: db).plannedNotifications()
            Task {
                await NotificationService.apply(planned)
            }
            errorText = nil
        } catch {
            errorText = "保存に失敗しました: \(error)"
        }
    }

    /// 通知の許可を求める。
    ///
    /// モデル(非 Sendable)を非同期境界に渡さないよう static にしている。
    /// DB は使わない。
    public static func requestAuthorization() async {
        _ = await NotificationService.requestAuthorization()
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

/// 通知設定(§8)。
///
/// **1 日 1 通まで。** 通知過多でオフにされると、忘れ防止の仕組みごと機能しなくなる。
public struct NotificationSettingsView: View {
    @State private var model = NotificationSettingsModel()

    private let weekdayNames = ["日", "月", "火", "水", "木", "金", "土"]

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

                Toggle(isOn: Binding(get: { model.isEnabled },
                                     set: { model.updateEnabled($0) })) {
                    Text("通知を受け取る", bundle: .module)
                }
                Text("1 日 1 通までにしています", bundle: .module)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if model.isEnabled {
                    practiceSection
                    eveningSection
                    scheduleSummary
                }
            }
            .padding()
        }
        .navigationTitle(Text("通知", bundle: .module))
        .task {
            model.load()
            await NotificationSettingsModel.requestAuthorization()
        }
    }

    /// 練習開始前 —— 今週の重点 3 つ(§8)。
    @ViewBuilder private var practiceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("練習の前に重点を知らせる", bundle: .module)
                .font(.headline)
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { weekday in
                    weekdayButton(weekday)
                }
            }
            stepperRow(Text("時刻", bundle: .module), hour: model.practiceHour) { hour in
                model.updatePracticeHour(hour)
            }
            Text("練習に行く曜日を選びます。選ばなければ出しません", bundle: .module)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private func weekdayButton(_ weekday: Int) -> some View {
        if model.isPracticeDay(weekday) {
            Button {
                model.togglePracticeDay(weekday)
            } label: {
                Text(verbatim: weekdayNames[weekday]).frame(minWidth: 28)
            }
            .buttonStyle(.borderedProminent)
        } else {
            Button {
                model.togglePracticeDay(weekday)
            } label: {
                Text(verbatim: weekdayNames[weekday]).frame(minWidth: 28)
            }
            .buttonStyle(.bordered)
        }
    }

    /// 大会当日の夜 / 週 1 回の stale(§8)。
    @ViewBuilder private var eveningSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("夜の通知", bundle: .module)
                .font(.headline)
            stepperRow(Text("時刻", bundle: .module), hour: model.eveningHour) { hour in
                model.updateEveningHour(hour)
            }
            Text("大会当日の振り返りと、しばらく触れていない課題の知らせに使います", bundle: .module)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private func stepperRow(_ label: Text, hour: Int, action: @escaping (Int) -> Void) -> some View {
        HStack {
            label
                .font(.footnote)
            Spacer()
            Button {
                action(hour > 0 ? hour - 1 : 23)
            } label: {
                Text(verbatim: "−")
            }
            .buttonStyle(.bordered)
            Text(verbatim: "\(hour) 時")
                .frame(minWidth: 56)
            Button {
                action(hour < 23 ? hour + 1 : 0)
            } label: {
                Text(verbatim: "+")
            }
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder private var scheduleSummary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("いま設定されている通知", bundle: .module)
                .font(.headline)
            Text(verbatim: "・練習前(\(model.practiceHour) 時): 今週の重点 3 つ")
            Text(verbatim: "・大会当日(\(model.eveningHour) 時): 振り返りを促す")
            Text(verbatim: "・毎週\(weekdayNames[model.reshuffleWeekday])曜(\(model.eveningHour) 時): しばらく触れていない課題")
            Text("同じ日に重なったときは、大会 → 触れていない課題 → 練習前 の順で 1 通だけ出します", bundle: .module)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .font(.footnote)
    }
}
