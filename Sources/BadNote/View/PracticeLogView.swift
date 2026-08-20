import SwiftUI

/// 練習ログ入力画面(§7.2)。
///
/// - 全項目任意。手応え未選択でも保存できる
/// - キーボードが必要なのは「時間」と「今日言われたこと」だけ
/// - ここで課題を整理させない(タグ・優先度・言い換えは別画面)
/// - 保存後は無言で閉じない
public struct PracticeLogView: View {
    @State private var model = PracticeLogModel()
    @Environment(\.dismiss) private var dismiss

    public init() {
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    errorSection
                    dateSection
                    minutesSection
                    kindSection
                    focusSection
                    coachWordsSection
                }
                .padding()
            }
            .navigationTitle(Text("練習を記録", bundle: .module))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("キャンセル", bundle: .module)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        model.save()
                    } label: {
                        Text("保存", bundle: .module)
                    }
                }
            }
            .alert(Text(model.summaryText), isPresented: $model.isShowingSummary) {
                Button {
                    dismiss()
                } label: {
                    Text("OK", bundle: .module)
                }
            }
        }
        .task {
            model.load()
        }
    }

    @ViewBuilder private var errorSection: some View {
        if let errorText = model.errorText {
            Text(errorText)
                .font(.footnote)
                .foregroundStyle(.red)
        }
    }

    // MARK: - 1. 日付

    @ViewBuilder private var dateSection: some View {
        DatePicker(selection: $model.practiceDate, displayedComponents: .date) {
            Text("日付", bundle: .module)
        }
    }

    // MARK: - 2. 練習時間

    @ViewBuilder private var minutesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(Text("練習時間", bundle: .module))

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(model.minutes)")
                    .font(.system(size: 52, weight: .semibold))
                Text("分", bundle: .module)
                    .font(.title3)
            }

            HStack(spacing: 8) {
                minutesChip(Text("+15分", bundle: .module), amount: 15)
                minutesChip(Text("+30分", bundle: .module), amount: 30)
                minutesChip(Text("+60分", bundle: .module), amount: 60)
                Button {
                    model.resetMinutes()
                } label: {
                    Text("リセット", bundle: .module)
                }
                .buttonStyle(.bordered)
            }

            TextField(text: $model.minutesText) {
                Text("直接入力", bundle: .module)
            }
            .textFieldStyle(.roundedBorder)
            #if !os(macOS)
            .keyboardType(.numberPad)
            #endif
        }
    }

    @ViewBuilder private func minutesChip(_ label: Text, amount: Int) -> some View {
        Button {
            model.addMinutes(amount)
        } label: {
            label
        }
        .buttonStyle(.bordered)
    }

    // MARK: - 3. 種類

    @ViewBuilder private var kindSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(Text("種類", bundle: .module))
            HStack(spacing: 8) {
                kindButton(Text("全体練習", bundle: .module), kind: .whole)
                kindButton(Text("個人練習", bundle: .module), kind: .individual)
                kindButton(Text("ゲーム練習", bundle: .module), kind: .game)
                kindButton(Text("筋トレ", bundle: .module), kind: .strength)
            }
            .font(.footnote)
        }
    }

    @ViewBuilder private func kindButton(_ label: Text, kind: PracticeKind) -> some View {
        if model.kind == kind {
            Button {
                model.toggleKind(kind)
            } label: {
                label
            }
            .buttonStyle(.borderedProminent)
        } else {
            Button {
                model.toggleKind(kind)
            } label: {
                label
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - 4. 今週の重点

    @ViewBuilder private var focusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(Text("今週の重点", bundle: .module))
            if model.focusInputs.isEmpty {
                Text("今週の重点はまだありません", bundle: .module)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(model.focusInputs) { input in
                VStack(alignment: .leading, spacing: 8) {
                    Text(input.title)
                        .font(.body)
                    HStack(spacing: 8) {
                        resultButton(Text("できた", bundle: .module), result: .done, input: input)
                        resultButton(Text("近づいた", bundle: .module), result: .closer, input: input)
                        resultButton(Text("次にやる", bundle: .module), result: .next, input: input)
                    }
                    .font(.footnote)
                }
                .padding(12)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }

    @ViewBuilder private func resultButton(_ label: Text, result: FocusResult, input: PracticeLogModel.FocusInput) -> some View {
        if input.result == result {
            Button {
                model.toggleResult(result, for: input.id)
            } label: {
                label
            }
            .buttonStyle(.borderedProminent)
        } else {
            Button {
                model.toggleResult(result, for: input.id)
            } label: {
                label
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - 5. 今日言われたこと

    @ViewBuilder private var coachWordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(Text("今日言われたこと(任意)", bundle: .module))

            ForEach(model.addedCoachWords, id: \.self) { words in
                HStack {
                    Text(words)
                        .font(.footnote)
                    Spacer()
                    Button {
                        removeCoachWords(words)
                    } label: {
                        Text("削除", bundle: .module)
                            .font(.footnote)
                    }
                }
            }

            TextField(text: $model.coachWordsDraft) {
                Text("言われたことを 1 行で", bundle: .module)
            }
            .textFieldStyle(.roundedBorder)

            Button {
                model.addCoachWords()
            } label: {
                Text("＋ もう 1 件追加", bundle: .module)
            }
            .buttonStyle(.bordered)
        }
    }

    private func removeCoachWords(_ words: String) {
        for index in 0..<model.addedCoachWords.count {
            if model.addedCoachWords[index] == words {
                model.removeCoachWords(at: index)
                return
            }
        }
    }

    @ViewBuilder private func sectionTitle(_ label: Text) -> some View {
        label
            .font(.headline)
    }
}
