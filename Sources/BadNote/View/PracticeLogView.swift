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

    /// 本人に聞く 1 手(§3.2)。**事実 → 問い**の順に置く(判断の材料を先に見せる)。
    ///
    /// **戻す提案は失敗に見せない。** 上げるときだけ承認を `.borderedProminent` にし、
    /// 戻すときは両方 `.bordered` —— アプリが下向きに背中を押さない。
    /// 克服は問いではなく**扉**なので、断るボタンを持たせない。
    @ViewBuilder private func offerCard(_ row: PracticeLogModel.OfferRow) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text(row.issue.displayTitle)
                    .font(.body)
                Text(row.offer.reasonText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(row.offer.promptText)
                    .font(.body)
                if row.offer.kind == MasteryOfferKind.overcome {
                    NavigationLink {
                        IssueDetailView(issueID: row.issue.id)
                    } label: {
                        Text(row.offer.acceptText)
                            .font(.footnote)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("practice-offer-overcome-\(row.id)")
                } else {
                    HStack(spacing: 8) {
                        acceptButton(row)
                        Button {
                            withAnimation(Motion.move) {
                                model.decline(row)
                            }
                        } label: {
                            Text("今はしない", bundle: .module)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("practice-offer-decline-\(row.id)")
                    }
                    .font(.footnote)
                }
            }
        }
    }

    /// 上げるときだけ強いボタン。戻すときは枠だけ(§3.2 失敗に見せない)。
    @ViewBuilder private func acceptButton(_ row: PracticeLogModel.OfferRow) -> some View {
        if row.offer.kind == MasteryOfferKind.levelUp {
            Button {
                withAnimation(Motion.move) {
                    model.accept(row)
                }
            } label: {
                Text(row.offer.acceptText)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("practice-offer-accept-\(row.id)")
        } else {
            Button {
                withAnimation(Motion.move) {
                    model.accept(row)
                }
            } label: {
                Text(row.offer.acceptText)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("practice-offer-accept-\(row.id)")
        }
    }

    @ViewBuilder private var savedSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            // §7.2 記録内容と今月の累計
            Text(model.summaryText)
                .font(.headline)

            // この保存で節目を越えた(§10.5)。静かに 1 行で祝う。
            // 振動は isSaved の .success がすでに鳴っているので重ねない
            ForEach(model.reachedMilestones, id: \.self) { hours in
                HStack(spacing: 8) {
                    Image("emoji_events", bundle: .module)
                        .foregroundStyle(Palette.accent)
                    Text(verbatim: "\(hours) 時間にとどきました")
                        .font(.headline)
                        .foregroundStyle(Palette.accent)
                }
                .accessibilityIdentifier("practice-milestone-\(hours)")
            }

            // §7.2 手応えを付けた課題の現在地。**提案が出た課題はここに出さない**
            // (提案カードが課題名と現在地を既に語っている)
            if !model.standings.isEmpty {
                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(model.standings) { row in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.issue.displayTitle)
                                    .font(.footnote)
                                Text(row.standing.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityIdentifier("practice-standing-\(row.id)")
                        }
                    }
                }
            }

            // §3.2 本人に聞く 1 手(上げる / 戻す / 克服)
            ForEach(model.offers) { row in
                offerCard(row)
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
