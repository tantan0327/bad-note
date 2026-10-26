import SwiftUI

/// 大会詳細(§7.5)。
///
/// 基本情報 / この大会までに / 調整期の帯 / 大会後の振り返り。
/// 当日を過ぎると振り返りのフォームに切り替わる。
public struct CompetitionDetailView: View {
    @State private var model: CompetitionDetailModel
    @State private var isShowingDeleteConfirmation = false
    @State private var isEditingAim = false
    @Environment(\.dismiss) private var dismiss

    public init(competitionID: Int64) {
        _model = State(initialValue: CompetitionDetailModel(competitionID: competitionID))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let errorText = model.errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundStyle(Palette.error)
                }
                if let competition = model.competition {
                    basicSection(competition)
                    // 「何をしに行くか」は課題より先(目標大会でなくても出す)
                    aimSection(competition)
                    if model.isAdjustmentPeriod {
                        adjustmentBanner
                    }
                    if model.isFinished {
                        reviewSection
                    } else {
                        issueSections
                    }
                }
            }
            .padding()
        }
        // タイトルは「大会」ではなく大会名そのもの(tasks.md 1.2)
        .navigationTitle(Text(model.competition?.name ?? ""))
        #if os(iOS) || os(Android)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                // 削除はメニューの奥に置く。気軽に消せる場所に置かない(§7.5)
                Menu {
                    NavigationLink {
                        CompetitionEditView(competitionID: model.competition?.id ?? 0)
                    } label: {
                        Text("編集する", bundle: .module)
                    }
                    .accessibilityIdentifier("competition-detail-edit")
                    Button(role: .destructive) {
                        isShowingDeleteConfirmation = true
                    } label: {
                        Text("この大会を削除", bundle: .module)
                    }
                    .accessibilityIdentifier("competition-detail-delete")
                } label: {
                    Text(verbatim: "⋯")
                }
                // 記号だけのボタンなので読み上げ用の名前を付ける(6.1)
                .accessibilityLabel(Text("その他の操作", bundle: .module))
                .accessibilityIdentifier("competition-detail-menu")
            }
        }
        .confirmationDialog(Text("この大会を削除しますか?", bundle: .module),
                            isPresented: $isShowingDeleteConfirmation,
                            titleVisibility: .visible) {
            Button(role: .destructive) {
                model.delete()
                dismiss()
            } label: {
                Text("削除する", bundle: .module)
            }
            Button(role: .cancel) {
            } label: {
                Text("やめる", bundle: .module)
            }
        }
        .sheet(isPresented: $isEditingAim) {
            aimEditor
        }
        .onAppear {
            model.load()
        }
    }

    // MARK: - 1.5 この大会でのねらい(目標大会でなくても持てる。§7.5)

    /// 大会版の小さな「めざす姿」。**書いてあれば主役の次に大きく、無ければ静かに誘う。**
    /// 達成 / 未達の判定はしない(アプリは解釈しない)。
    ///
    /// 終了した大会では**書いたねらいを記録として引用**し、この下に続く振り返りと
    /// 前 / 後で対にする。終わった大会に「ねらいを決める」とは促さない。
    @ViewBuilder private func aimSection(_ competition: Competition) -> some View {
        let aim = competition.aim ?? ""
        if !aim.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("この大会でのねらい", bundle: .module)
                    .font(.headline)
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(aim)
                            .font(.title2)
                            .foregroundStyle(.primary)
                        if !model.isFinished {
                            Button {
                                model.beginEditingAim()
                                isEditingAim = true
                            } label: {
                                Text("編集する", bundle: .module)
                                    .font(.footnote)
                            }
                            .accessibilityIdentifier("competition-aim-edit")
                        }
                    }
                    .accessibilityIdentifier("competition-aim")
                }
            }
        } else if !model.isFinished {
            VStack(alignment: .leading, spacing: 8) {
                Text("この大会でのねらい", bundle: .module)
                    .font(.headline)
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        // 促すが強制しない(入力は原則すべて任意)
                        Text("何をしに行くかが決まると、当日までの練習に意味が出ます", bundle: .module)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Button {
                            model.beginEditingAim()
                            isEditingAim = true
                        } label: {
                            Text("ねらいを決める", bundle: .module)
                                .font(.footnote)
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("competition-aim-empty")
                    }
                }
            }
        }
    }

    @ViewBuilder private var aimEditor: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("この大会で何をするかを 1 行で決めます。結果ではなく、自分の動きで書くと振り返りやすくなります", bundle: .module)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    TextField(text: $model.aimText) {
                        Text("例: サーブレシーブで先に攻める", bundle: .module)
                    }
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("competition-aim-field")
                }
                .padding()
            }
            .navigationTitle(Text("この大会でのねらい", bundle: .module))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        isEditingAim = false
                    } label: {
                        Text("閉じる", bundle: .module)
                    }
                    .accessibilityIdentifier("competition-aim-close")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        withAnimation(Motion.select) {
                            model.saveAim()
                        }
                        isEditingAim = false
                    } label: {
                        Text("保存", bundle: .module)
                    }
                    .accessibilityIdentifier("competition-aim-save")
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - 1. 基本情報

    @ViewBuilder private func basicSection(_ competition: Competition) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(competition.name)
                .font(.title2)
            Text(DateText.dayWithWeekday(competition.eventDate))
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let venue = competition.venue, !venue.isEmpty {
                Text(venue)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if !model.isFinished {
                // 画面の主数字はホームのカウントダウンと同じ大きさ(tasks.md 1.2)
                Text(remainingText())
                    .font(.system(size: 34, weight: .semibold))
                // §5.2 予定日が未設定なら回数が出ないので、その場で決められるようにする
                if !model.hasPracticePlan {
                    NavigationLink {
                        PracticePlanView()
                    } label: {
                        Text("練習予定日を決めると、あと何回練習できるかが出ます", bundle: .module)
                            .font(.footnote)
                    }
                    .accessibilityIdentifier("competition-practice-plan")
                }
            } else {
                Text("終了しました", bundle: .module)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// 「あと 42日 / 12回」。練習予定日が未設定なら日数だけ(§5.2)。
    private func remainingText() -> String {
        return RemainingText.text(remainingDays: model.remainingDays,
                                  remainingPractices: model.remainingPractices)
    }

    // MARK: - 3. 調整期の帯

    @ViewBuilder private var adjustmentBanner: some View {
        Card(background: Palette.surfaceRaised) {
            Text("調整期です。新しい課題は増やさず、今の 3 つに集中します", bundle: .module)
                .font(.footnote)
        }
    }

    // MARK: - 2. この大会までに

    @ViewBuilder private var issueSections: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("この大会までに", bundle: .module)
                .font(.headline)
            if model.sections.isEmpty {
                Text("出場する種目が登録されていません", bundle: .module)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(model.sections) { section in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(section.discipline.displayName)
                            .font(.subheadline)
                        if section.isTarget {
                            Text("★ 目標大会", bundle: .module)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if section.issues.isEmpty {
                        Text("紐付いた課題はありません", bundle: .module)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(section.issues) { issue in
                        Card {
                            NavigationLink {
                                IssueDetailView(issueID: issue.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(issue.displayTitle)
                                        .font(.body)
                                    if section.isTight(issue) {
                                        // §7.5 控えめに提示する。警告にしない
                                        Text("この大会では厳しいかもしれません", bundle: .module)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .foregroundStyle(.primary)
                            }
                            .accessibilityIdentifier("competition-issue-\(issue.id)")
                        }
                    }
                }
            }
        }
    }

    // MARK: - 4. 大会後の振り返り(種目ごとに 1 セット)

    @ViewBuilder private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text("振り返り", bundle: .module)
                    .font(.headline)
                // 大会直後に空欄が 4 つ並ぶと手が止まる。**全部埋めなくていい**と先に言う
                // (CLAUDE.md「入力項目は原則すべて任意。必須項目を増やすと記録されなくなる」)
                Text("結果だけでも保存できます。空のままの欄があっても構いません", bundle: .module)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(0..<model.reviews.count, id: \.self) { index in
                reviewForm(index)
            }
        }
    }

    @ViewBuilder private func reviewForm(_ index: Int) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text(model.reviews[index].discipline.displayName)
                    .font(.subheadline)

                // 欄ごとに書く量が違うので、1 行と複数行を使い分ける(1.6)
                field(Text("結果", bundle: .module),
                      placeholder: Text("例: 2回戦敗退", bundle: .module),
                      text: $model.reviews[index].result)
                // ここだけ数行になりやすい。1 行欄で書かせない
                longField(Text("うまくいったことは何か", bundle: .module),
                          example: Text("例: サーブレシーブで先に攻められた", bundle: .module),
                          text: $model.reviews[index].wentWell)
                // この欄はそのまま課題の 1 行になるので、課題の書き方に合わせて 1 行のまま
                field(Text("理想の姿に近づくために次にやることは何か", bundle: .module),
                      placeholder: Text("例: 後ろに下がる判断を先に出す", bundle: .module),
                      text: $model.reviews[index].nextAction)
                field(Text("そのために必要なもの(人・道具・情報)は何か", bundle: .module),
                      placeholder: Text("例: 試合の動画を撮ってもらう", bundle: .module),
                      text: $model.reviews[index].neededResources)

                HStack(spacing: 8) {
                    Button {
                        model.saveReview(model.reviews[index])
                    } label: {
                        Text("保存", bundle: .module)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("competition-review-save-\(model.reviews[index].discipline.rawValue)")
                    // §7.5 3 つ目の回答からそのまま課題を登録できる導線。
                    // **空のときは押せなくする**(1.6)—— それまでは押せるのに黙って
                    // 何も起きず、押した側には失敗したのか成功したのか分からなかった
                    Button {
                        model.createIssueFromNextAction(model.reviews[index])
                    } label: {
                        Text("次にやることを課題にする", bundle: .module)
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.reviews[index].nextAction.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("competition-review-to-issue-\(model.reviews[index].discipline.rawValue)")
                }
                .font(.footnote)
                // **押した場所の隣に出す**(2026-10-27)。
                // それまでは画面のいちばん上に出ていて、
                // 下までスクロールして保存した人の目には入らなかった
                if let savedMessage = model.savedMessage {
                    Text(savedMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("competition-review-saved")
                }
            }
        }
    }

    /// 1 行で書く欄。**プレースホルダに例を置く**(1.6)——
    /// 空欄が並ぶだけだと何を書けばいいか分からず、手が止まる。
    @ViewBuilder private func field(_ label: Text, placeholder: Text, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            label
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(text: text) {
                placeholder
            }
            .textFieldStyle(.roundedBorder)
        }
    }

    /// 数行になりやすい欄。`TextEditor` はプレースホルダを持てないので、
    /// 例はラベルの下に置く(めざす姿の編集と同じ形)。
    @ViewBuilder private func longField(_ label: Text, example: Text, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            label
                .font(.caption)
                .foregroundStyle(.secondary)
            example
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: text)
                .frame(minHeight: 88)
                .border(Color.secondary.opacity(0.4), width: 1)
        }
    }
}
