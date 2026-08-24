import SwiftUI

/// 練習ログ入力画面(§7.2)。
///
/// - 全項目任意。手応え未選択でも保存できる
/// - キーボードが必要なのは「時間」と「追加する課題」だけ
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
                    if model.isSaved {
                        savedSection
                    } else {
                        dateSection
                        minutesSection
                        kindSection
                        focusSection
                        coachWordsSection
                    }
                }
                .padding()
            }
            .navigationTitle(Text("練習を記録", bundle: .module))
            // 5.2 画面を見ずに操作する場所の触覚。手応えの選択は軽く、保存できたら成功
            .sensoryFeedback(SensoryFeedback.selection, trigger: model.selectionCount)
            .sensoryFeedback(SensoryFeedback.success, trigger: model.isSaved) { old, new in
                !old && new
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("閉じる", bundle: .module)
                    }
                    .accessibilityIdentifier("practice-close")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        // 保存後の表示への切り替わりを動かす(5.1)
                        withAnimation(Motion.move) {
                            model.save()
                        }
                    } label: {
                        Text("保存", bundle: .module)
                    }
                    .disabled(model.isSaved)
                    .accessibilityIdentifier("practice-save")
                }
            }
        }
        .task {
            model.load()
        }
    }

    // MARK: - 保存後(無言で閉じない)

    @ViewBuilder private var savedSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            // §7.2 記録内容と今月の累計
            Text(model.summaryText)
                .font(.headline)

            // §3.2 done が 3 回連続した課題のレベルアップ提案
            ForEach(model.levelUpProposals) { proposal in
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(proposal.issue.displayTitle)
                            .font(.body)
                        Text(verbatim: "「\(proposal.suggestedLevel.displayName)」に上げますか?")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            Button {
                                withAnimation(Motion.move) {
                                    model.acceptLevelUp(proposal)
                                }
                            } label: {
                                Text("上げる", bundle: .module)
                            }
                            .buttonStyle(.borderedProminent)
                            Button {
                                withAnimation(Motion.move) {
                                    model.declineLevelUp(proposal)
                                }
                            } label: {
                                Text("今はしない", bundle: .module)
                            }
                            .buttonStyle(.bordered)
                        }
                        .font(.footnote)
                    }
                }
            }

            // §5.3 未整理の促し。ここでだけ聞く(常設のバッジにはしない)
            if model.unorganizedCount > 0 {
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(verbatim: "\(model.unorganizedCount) 件が未整理です")
                            .font(.body)
                        Text("いま整理しますか?", bundle: .module)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        NavigationLink {
                            InboxTriageView()
                        } label: {
                            Text("整理する", bundle: .module)
                        }
                        .buttonStyle(.bordered)
                        .font(.footnote)
                    }
                }
            }

            Button {
                dismiss()
            } label: {
                Text("閉じる", bundle: .module)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("practice-done")
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

            // §7.2「大きい数字 + チップ + リセット。直接入力も可」——
            // 大きい数字そのものを入力欄にして、表示と入力を 1 つにまとめている
            //
            // `#if !os(macOS)` だと Skip が Android 側でも中身を落とすため、
            // 対象 OS を並べて書く。落ちるとフルキーボードが出てしまう。
            HStack(spacing: 8) {
                TextField(text: $model.minutesText) {
                    Text(verbatim: "0")
                }
                .font(.system(size: 52, weight: .semibold))
                .multilineTextAlignment(.center)
                // 枠が無いと、iOS では大きい数字がただの表示に見えて押されない
                .textFieldStyle(.roundedBorder)
                .frame(width: 150)
                #if os(iOS) || os(Android)
                .keyboardType(.numberPad)
                #endif
                .accessibilityIdentifier("practice-minutes")
                Text("分", bundle: .module)
                    .font(.title3)
                Spacer()
            }

            // 足すチップとリセットは役割が違う。同じ枠のボタンで横に並べると
            // 幅を取り合って「リセッ ト」と割れるので、リセットは文字だけにして右端に置く
            HStack(spacing: 8) {
                minutesChip(Text("+15分", bundle: .module), amount: 15)
                minutesChip(Text("+30分", bundle: .module), amount: 30)
                minutesChip(Text("+60分", bundle: .module), amount: 60)
                Spacer()
                Button {
                    model.resetMinutes()
                } label: {
                    Text("リセット", bundle: .module)
                }
                .buttonStyle(.borderless)
                .chipLabelFit()
            }
        }
    }

    @ViewBuilder private func minutesChip(_ label: Text, amount: Int) -> some View {
        Button {
            model.addMinutes(amount)
        } label: {
            label
        }
        .buttonStyle(.bordered)
        .chipLabelFit()
    }

    // MARK: - 3. 種類

    @ViewBuilder private var kindSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(Text("種類", bundle: .module))
            // 4 つを 1 行に詰めると Android で「全体練 習」と割れる。
            // 2 行に分けて均等幅にすると、文字を小さくしなくても収まる
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    kindButton(Text(PracticeKind.whole.displayName), kind: .whole)
                    kindButton(Text(PracticeKind.individual.displayName), kind: .individual)
                }
                HStack(spacing: 8) {
                    kindButton(Text(PracticeKind.game.displayName), kind: .game)
                    kindButton(Text(PracticeKind.strength.displayName), kind: .strength)
                }
            }
        }
    }

    @ViewBuilder private func kindButton(_ label: Text, kind: PracticeKind) -> some View {
        SelectableChip(label: label, isSelected: model.kind == kind) {
            model.toggleKind(kind)
        }
        .accessibilityIdentifier("practice-kind-\(kind.rawValue)")
    }

    // MARK: - 4. 今週の重点

    @ViewBuilder private var focusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(Text("今週の重点", bundle: .module))
            if model.focusInputs.isEmpty {
                // 練習ログ入力では課題を整理させない(§7.2)ので、ここに導線は置かない
                EmptyStateView(icon: "checklist",
                               message: Text("今週の重点はまだありません", bundle: .module)) {
                    EmptyView()
                }
            }
            ForEach(model.focusInputs) { input in
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(input.title)
                            .font(.body)
                        HStack(spacing: 8) {
                            resultButton(Text(FocusResult.done.displayName), result: .done, input: input)
                            resultButton(Text(FocusResult.closer.displayName), result: .closer, input: input)
                            resultButton(Text(FocusResult.next.displayName), result: .next, input: input)
                        }
                        .font(.footnote)
                    }
                }
            }
        }
    }

    @ViewBuilder private func resultButton(_ label: Text, result: FocusResult, input: PracticeLogModel.FocusInput) -> some View {
        SelectableChip(label: label, isSelected: input.result == result) {
            model.toggleResult(result, for: input.id)
        }
        .accessibilityIdentifier("practice-result-\(input.id)-\(result.rawValue)")
    }

    // MARK: - 5. 追加する課題

    @ViewBuilder private var coachWordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(Text("追加する課題(任意)", bundle: .module))

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
                Text("課題を 1 行で", bundle: .module)
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
