import Foundation
import Observation
import SwiftUI
import SkipSQL

/// 練習予定日の状態(§5.2 / §7.6)。
@Observable public final class PracticePlanModel {

    /// これからの予定日(古い順)。過ぎた日は出さない
    public private(set) var days: [PracticePlanDay] = []
    /// 表示中の月(その月の 1 日 0 時)
    public private(set) var displayedMonth = Date()
    /// 表示中の 42 セル
    public private(set) var cells: [MonthGridDay] = []
    /// 遠い月へ飛ぶための日付
    public var jumpDate = Date()
    public var errorText: String? = nil

    /// 42 セルの範囲にある登録済みの日。**見えているぶんだけ**読む
    private var visiblePlanDays: [PracticePlanDay] = []
    /// 今日の 0 時。過去判定の基準
    private var today = Date()
    private var isStarted = false

    public init() {
    }

    /// 画面に入ったときに呼ぶ。**表示月を決めるのは初回だけ。**
    ///
    /// まとめて追加から戻ると `onAppear` が再発火するので、毎回月を戻すと
    /// 12 月を見ていた人が今月に飛ばされる。
    public func appear(now: Date = Date()) {
        if isStarted {
            load()
            return
        }
        isStarted = true
        today = Calendar.current.startOfDay(for: now)
        displayedMonth = MonthRange.containing(now).start
        jumpDate = now
        load()
    }

    /// 読み直し。**表示月は動かさない。**
    public func load() {
        cells = MonthGrid.cells(of: displayedMonth)
        do {
            let repo = try repository()
            if let first = cells.first, let last = cells.last {
                visiblePlanDays = try repo.fetchRange(from: first.date, through: last.date)
            }
            // 月を送っても一覧は必ず更新する(先の月の日を足したら一覧にも出る)
            days = try repo.fetchUpcoming(asOf: today)
            errorText = nil
        } catch {
            errorText = "練習予定日の読み込みに失敗しました: \(error)"
        }
    }

    // MARK: - 月を動かす

    public func showPreviousMonth() {
        displayedMonth = MonthGrid.shifted(displayedMonth, by: -1)
        load()
    }

    public func showNextMonth() {
        displayedMonth = MonthGrid.shifted(displayedMonth, by: 1)
        load()
    }

    public func jumpToPickedMonth() {
        displayedMonth = MonthRange.containing(jumpDate).start
        load()
    }

    public var monthTitle: String {
        return DateText.month(displayedMonth)
    }

    // MARK: - セル

    /// 範囲チェック付きの取り出し。`MonthGrid` は常に 42 個を返すが、
    /// 万一足りなくても**落ちるより空白のほうがまし**。
    public func cell(week: Int, weekday: Int) -> MonthGridDay? {
        let index = week * MonthGrid.dayCount + weekday
        if index < 0 || index >= cells.count {
            return nil
        }
        return cells[index]
    }

    public func isPlanned(_ cell: MonthGridDay) -> Bool {
        return PracticePlan.planned(visiblePlanDays, on: cell.date) != nil
    }

    /// 押せるのは**表示中の月**の、**今日以降**の日だけ。
    /// 今日を含めるのは §5.2「今日は数える」と揃えるため。
    public func isSelectable(_ cell: MonthGridDay) -> Bool {
        return cell.isInMonth && cell.date >= today
    }

    public func isToday(_ cell: MonthGridDay) -> Bool {
        return cell.date == today
    }

    /// タップで入れる / 外す。**押した瞬間に保存する。**
    public func toggle(_ cell: MonthGridDay) {
        // View 側でも押せないが、二重の門番にしておく
        if !isSelectable(cell) {
            return
        }
        do {
            let repo = try repository()
            if let existing = PracticePlan.planned(visiblePlanDays, on: cell.date) {
                try repo.remove(existing)
            } else {
                try repo.add(cell.date)
            }
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

/// 練習予定日(§5.2 / §7.6)。設定から開く。
///
/// **ここに登録した日数が、そのまま大会までの「あと N回」になる。**
/// 練習前の通知(§8)もこの日にだけ出る。
///
/// 月カレンダーの日をタップして入れる / 外す。**カレンダーがそのまま今の予定表**になる。
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
                // **カレンダー全体を 1 つの行に収める。** 週ごとに行を分けると
                // List の区切り線が格子の中に 5 本入り、列もずれる
                calendar
                DatePicker(selection: $model.jumpDate, displayedComponents: .date) {
                    Text("別の月へ", bundle: .module)
                        .font(.footnote)
                }
                .accessibilityIdentifier("practice-plan-picker")
                .onChange(of: model.jumpDate) { _, _ in
                    model.jumpToPickedMonth()
                }
            } header: {
                Text("予定日を選ぶ", bundle: .module)
            } footer: {
                Text("日をタップすると予定日になります。もう一度タップすると外れます。過ぎた日は変えられません",
                     bundle: .module)
                    .font(.caption)
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
                Text("大会までの「あと何回」はこの日数で数えます", bundle: .module)
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
            model.appear()
        }
    }

    // MARK: - カレンダー

    @ViewBuilder private var calendar: some View {
        VStack(spacing: 8) {
            HStack {
                Button {
                    withAnimation(Motion.move) {
                        model.showPreviousMonth()
                    }
                } label: {
                    Text("前の月", bundle: .module)
                        .font(.footnote)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("practice-plan-previous-month")
                Spacer()
                Text(model.monthTitle)
                    .font(.headline)
                Spacer()
                Button {
                    withAnimation(Motion.move) {
                        model.showNextMonth()
                    }
                } label: {
                    Text("次の月", bundle: .module)
                        .font(.footnote)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("practice-plan-next-month")
            }

            // 列の間隔は 2。4 の倍数の原則の例外 —— `listRowInsets` が使えず
            // 幅が「画面幅 − 32」で決まってしまうので、7 列に配るとこれ以上取れない
            HStack(spacing: 2) {
                ForEach(0..<7, id: \.self) { weekday in
                    Text(verbatim: WeekdayName.of(weekday))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            ForEach(0..<6, id: \.self) { week in
                HStack(spacing: 2) {
                    ForEach(0..<7, id: \.self) { weekday in
                        dayCell(week: week, weekday: weekday)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    /// カレンダーの 1 マス。状態は 3 つ。
    ///
    /// **`.bordered` / `.borderedProminent` は使えない** —— Material のボタンは
    /// 左右 24dp の余白と最小幅を持つので、7 個並べると 2 桁の数字が押し出されて消える。
    /// `.plain` は Android では「ラベルに clickable を貼るだけ」なので、
    /// `.frame` がそのままタップ領域になる。塗りは自前で描く。
    @ViewBuilder private func dayCell(week: Int, weekday: Int) -> some View {
        if let cell = model.cell(week: week, weekday: weekday) {
            if model.isSelectable(cell) {
                Button {
                    withAnimation(Motion.select) {
                        model.toggle(cell)
                    }
                } label: {
                    dayLabel(cell)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("practice-plan-day-\(week)-\(weekday)")
                .accessibilityLabel(Text(DateText.dayWithWeekday(cell.date)))
            } else {
                // **押せないセルは Button にしない。** disabled にすると
                // VoiceOver が 42 個中 15 個を空振りの操作対象として読み上げる
                dayLabel(cell)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder private func dayLabel(_ cell: MonthGridDay) -> some View {
        // 数字は書式を持たないので DateText を通さない(読み上げ用のラベルは通している)
        Text(verbatim: "\(cell.dayNumber)")
            .font(.footnote)
            .foregroundStyle(dayColor(cell))
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(model.isPlanned(cell) && cell.isInMonth ? Palette.accent : Color.clear)
            .cornerRadius(8)
            .overlay(todayBorder(cell))
    }

    private func dayColor(_ cell: MonthGridDay) -> Color {
        if model.isPlanned(cell) && cell.isInMonth {
            return Color.white
        }
        if !cell.isInMonth || !model.isSelectable(cell) {
            return Color.secondary
        }
        return Color.primary
    }

    /// 今日の位置の手がかり。日付ピッカーを主役から外したぶん、これが無いと現在地を見失う。
    @ViewBuilder private func todayBorder(_ cell: MonthGridDay) -> some View {
        if model.isToday(cell) {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Palette.accent, lineWidth: 1)
        }
    }
}
