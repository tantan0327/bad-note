import Foundation
import Observation
import SwiftUI
import SkipSQL

/// 通知設定の状態(§8)。
@Observable public final class NotificationSettingsModel {

    public var isEnabled = false
    public var practiceWeekdays: [Int] = []
    public var practiceHour = 18
    public var practiceMinute = 0
    public var eveningHour = 20
    public var eveningMinute = 0
    public var reshuffleWeekday = 0
    public var errorText: String? = nil


    public init() {
    }

    public func load() {
        do {
            let settings = try AppMetaRepository(db: try context()).notificationSettings()
            isEnabled = settings.isEnabled
            practiceWeekdays = settings.practiceWeekdays
            practiceHour = settings.practiceHour
            practiceMinute = settings.practiceMinute
            eveningHour = settings.eveningHour
            eveningMinute = settings.eveningMinute
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

    /// DatePicker(時:分)から受ける(2.5)。日付部分は捨てて時・分だけ使う。
    public func updatePracticeTime(_ date: Date) {
        let calendar = Calendar.current
        practiceHour = calendar.component(Calendar.Component.hour, from: date)
        practiceMinute = calendar.component(Calendar.Component.minute, from: date)
        save()
    }

    public func updateEveningTime(_ date: Date) {
        let calendar = Calendar.current
        eveningHour = calendar.component(Calendar.Component.hour, from: date)
        eveningMinute = calendar.component(Calendar.Component.minute, from: date)
        save()
    }

    /// DatePicker に渡す Date。今日の日付に時・分を載せるだけ(使うのは時・分のみ)。
    public static func time(hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([Calendar.Component.year, Calendar.Component.month, Calendar.Component.day], from: Date())
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components) ?? Date()
    }

    /// 「18:05」の形。まとめ表示用。
    public static func timeText(hour: Int, minute: Int) -> String {
        let padded = minute < 10 ? "0\(minute)" : "\(minute)"
        return "\(hour):\(padded)"
    }

    /// 変更のたびに保存して予定を入れ直す。**設定と実際の通知をずらさない。**
    public func save() {
        do {
            let db = try context()
            try AppMetaRepository(db: db).setNotificationSettings(NotificationSettings(isEnabled: isEnabled,
                                                                                       practiceWeekdays: practiceWeekdays,
                                                                                       practiceHour: practiceHour,
                                                                                       practiceMinute: practiceMinute,
                                                                                       eveningHour: eveningHour,
                                                                                       eveningMinute: eveningMinute,
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
        // 共有接続(6.3)。モデルごとに開くと database is locked を踏む
        return try AppDatabase.shared()
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
                .accessibilityIdentifier("notification-enabled")
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
            timeRow(hour: model.practiceHour, minute: model.practiceMinute) { date in
                model.updatePracticeTime(date)
            }
            .accessibilityIdentifier("notification-practice-time")
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
            .accessibilityIdentifier("notification-weekday-\(weekday)")
        } else {
            Button {
                model.togglePracticeDay(weekday)
            } label: {
                Text(verbatim: weekdayNames[weekday]).frame(minWidth: 28)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("notification-weekday-\(weekday)")
        }
    }

    /// 大会当日の夜 / 週 1 回の stale(§8)。
    @ViewBuilder private var eveningSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("夜の通知", bundle: .module)
                .font(.headline)
            timeRow(hour: model.eveningHour, minute: model.eveningMinute) { date in
                model.updateEveningTime(date)
            }
            .accessibilityIdentifier("notification-evening-time")
            Text("大会当日の振り返りと、しばらく触れていない課題の知らせに使います", bundle: .module)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// 時刻は DatePicker で一発指定(2.5)。−/+ で 11 回押させない。
    @ViewBuilder private func timeRow(hour: Int, minute: Int, action: @escaping (Date) -> Void) -> some View {
        DatePicker(selection: Binding(get: { NotificationSettingsModel.time(hour: hour, minute: minute) },
                                      set: { action($0) }),
                   displayedComponents: .hourAndMinute) {
            Text("時刻", bundle: .module)
                .font(.footnote)
        }
    }

    @ViewBuilder private var scheduleSummary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("いま設定されている通知", bundle: .module)
                .font(.headline)
            Text(verbatim: "・練習前(\(NotificationSettingsModel.timeText(hour: model.practiceHour, minute: model.practiceMinute))): 今週の重点 3 つ")
            Text(verbatim: "・大会当日(\(NotificationSettingsModel.timeText(hour: model.eveningHour, minute: model.eveningMinute))): 振り返りを促す")
            Text(verbatim: "・毎週\(weekdayNames[model.reshuffleWeekday])曜(\(NotificationSettingsModel.timeText(hour: model.eveningHour, minute: model.eveningMinute))): しばらく触れていない課題")
            Text("同じ日に重なったときは、大会 → 触れていない課題 → 練習前 の順で 1 通だけ出します", bundle: .module)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .font(.footnote)
    }
}
