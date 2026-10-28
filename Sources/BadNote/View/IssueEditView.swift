import SwiftUI

/// 課題の登録・編集画面(§3)。
///
/// 新規で必須なのは原文の 1 行だけ。他はすべて任意で、後から編集できる。
public struct IssueEditView: View {
    @State private var model: IssueEditModel
    @State private var isShowingDetails = false
    @State private var isShowingDeleteConfirmation = false
    @Environment(\.dismiss) private var dismiss

    /// - Parameter issueID: nil なら新規登録。
    public init(issueID: Int64? = nil) {
        _model = State(initialValue: IssueEditModel(issueID: issueID))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let errorText = model.errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundStyle(Palette.error)
                }
                // **欄は 1 つだけ**(2026-10-12)。追加でも編集でも同じ姿にする ——
                // 追加が 1 欄で編集が 2 欄だと「さっき書いたのにまだ書く欄がある」と見える
                titleSection
                // 残りはすべて任意で、既定値があり、後から変えられる。
                // 同じ重さで並べると記入必須のフォームに見えるので畳んでおく
                DisclosureGroup(isExpanded: $isShowingDetails) {
                    VStack(alignment: .leading, spacing: 24) {
                        if !model.isNew {
                            originalWordsSection
                        }
                        disciplineSection
                        masterySection
                        impactSection
                        costSection
                        tagSection
                    }
                    .padding(.top, 12)
                } label: {
                    Text("くわしく決める(任意)", bundle: .module)
                        .font(.headline)
                }
                .accessibilityIdentifier("issue-edit-details")
                deleteSection
            }
            .padding()
        }
        // **何が消えるかを押す前に書く。** 黙って利用者のデータを消さない。
        // 練習ログそのものは残るので、そこも書く(消えたと誤解させない)
        .confirmationDialog(Text("この課題を削除しますか?", bundle: .module),
                            isPresented: $isShowingDeleteConfirmation,
                            titleVisibility: .visible) {
            Button(role: .destructive) {
                model.delete()
                dismiss()
            } label: {
                Text("削除する", bundle: .module)
            }
            .accessibilityIdentifier("issue-edit-delete-confirm")
            Button(role: .cancel) {
            } label: {
                Text("やめる", bundle: .module)
            }
        } message: {
            Text("この課題の手応えの記録も一緒に消えます。練習の記録は残ります。戻せません", bundle: .module)
        }
        .navigationTitle(model.isNew ? Text("課題を追加", bundle: .module) : Text("課題を編集", bundle: .module))
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    model.save()
                    if model.isSaved {
                        dismiss()
                    }
                } label: {
                    Text("保存", bundle: .module)
                }
                // 画面の下にいると、最上部のエラー文は見えない。押せないことで伝える
                .disabled(!model.canSave)
                .accessibilityIdentifier("issue-edit-save")
            }
        }
        .task {
            model.load()
        }
    }

    // MARK: - 課題(画面に出るただ 1 つの欄)

    /// **追加でも編集でも同じ 1 欄。**
    ///
    /// 新規ならここに書いた文が書き留めた言葉になり、編集なら言い換えに入る
    /// (`IssueTitleEdit`)。書き留めた言葉は残るので、原文を失うことはない。
    // MARK: - 削除(いちばん下)

    /// 課題を消す道(2026-10-18)。
    ///
    /// **課題詳細の右上から移した。** そこでは「編集」の隣に「⋯」が並び、
    /// 文字のボタンと記号のボタンがくっついて 1 つのボタンに見えていた。
    ///
    /// 編集画面の末尾は、連絡先やカレンダーが削除を置く場所でもある。
    /// 一覧 → 詳細 → 編集 と 2 つ入った先なので、§7.5 の
    /// 「気軽に消せる場所に置かない」も満たしている。
    ///
    /// **新規では出さない** —— まだ保存されていないので消すものが無い。
    @ViewBuilder private var deleteSection: some View {
        if !model.isNew {
            VStack(alignment: .leading, spacing: 8) {
                // **`Divider()` は置かない**(2026-10-19 に踏んだ)——
                // ここに入れると編集画面を開いた瞬間にメインスレッドが止まり、
                // 画面が遷移しないまま固まった(Maestro が「main thread busy 30s」と出した)
                Button(role: .destructive) {
                    isShowingDeleteConfirmation = true
                } label: {
                    Text("この課題を削除", bundle: .module)
                        .font(.footnote)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("issue-edit-delete")
                // 「克服した」と間違えさせない。**どちらも課題を一覧から消す**ので、
                // 違いは戻せるかどうかだと先に書いておく
                Text("もう使わない課題を消します。克服した課題は、課題の画面から「克服した」を選んでください", bundle: .module)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 16)
        }
    }

    @ViewBuilder private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("課題", bundle: .module)
                .font(.headline)
            TextField(text: $model.title) {
                Text("例: 面が寝ていると言われた", bundle: .module)
            }
            .textFieldStyle(.roundedBorder)
            .accessibilityIdentifier("issue-edit-words")
            saveHint
            if model.isNew {
                writingGuide
            }
        }
    }

    /// 書き方の迷いを消すための例(2026-10-28)。
    ///
    /// **「おすすめ」をやめた。** それまでは
    /// 「「〜できている」の形で書くのがおすすめです。言われた言葉のままでも構いません」
    /// の 1 文だった。**勧めたうえで許すと、勧められていないほうが間違いに見える。**
    /// 初めて使う人が「できていないことを書くのか、できている状態を書くのか」で
    /// 止まる、という声が実際に出た。
    ///
    /// どちらでも本当に動く(整理の画面で後から言い換えられる)ので、
    /// **抽象的な助言をやめて、2 つの書き方を実物で並べる。**
    /// 出すのは**追加のときだけ** —— 編集で開く人はもう書き方を知っている。
    @ViewBuilder private var writingGuide: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("どちらの書き方でも大丈夫です。あとから直せます", bundle: .module)
                .font(.caption)
                .foregroundStyle(.secondary)
            // **例は面に載せて、まわりの説明文と分ける。**
            // 同じ灰色の文を 4 行並べたら、どれが例なのか読み取れなかった
            // (2026-10-28 に実機で確認して作り直した)
            Card {
                VStack(alignment: .leading, spacing: 12) {
                    guideExample(Text("言われたまま", bundle: .module),
                                 Text("面が寝ていると言われた", bundle: .module))
                    guideExample(Text("できている形", bundle: .module),
                                 Text("ラケット面を立てて構えられている", bundle: .module))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder private func guideExample(_ label: Text, _ example: Text) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            label
                .font(.caption)
                .foregroundStyle(.secondary)
            example
                .font(.footnote)
                .foregroundStyle(.primary)
        }
    }

    /// 保存が灰色のままになる理由。**必須の欄のすぐ下に置く** ——
    /// 画面の最上部にだけ出すと、下までスクロールして押した人には見えない。
    @ViewBuilder private var saveHint: some View {
        if !model.canSave {
            Text("この 1 行を入れると保存できます", bundle: .module)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - もとの言葉(折りたたみの中。言い換える前に何と言われたか)

    /// **上の 1 行を直しても、ここは変わらない。**
    /// 言われたとおりの言葉を残すのがこの欄の役目(§3.1)。誤字だけは直せる。
    @ViewBuilder private var originalWordsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("もとの言葉", bundle: .module)
                .font(.headline)
            TextField(text: $model.coachWords) {
                Text("気づいたことを 1 行で", bundle: .module)
            }
            .textFieldStyle(.roundedBorder)
            .accessibilityIdentifier("issue-edit-original")
            Text("最初に書き留めた言葉です。直すのは誤字くらいに留めます", bundle: .module)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(text: $model.coachName) {
                Text("コーチ名(任意)", bundle: .module)
            }
            .textFieldStyle(.roundedBorder)
            .accessibilityIdentifier("issue-edit-coach")
        }
    }

    // MARK: - 種目

    @ViewBuilder private var disciplineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("種目", bundle: .module)
                .font(.headline)
            HStack(spacing: 8) {
                disciplineButton(Text(Discipline.singles.displayName), value: .singles)
                disciplineButton(Text(Discipline.doubles.displayName), value: .doubles)
                disciplineButton(Text(Discipline.both.displayName), value: .both)
            }
            .font(.footnote)
        }
    }

    @ViewBuilder private func disciplineButton(_ label: Text, value: Discipline) -> some View {
        if model.discipline == value {
            Button { withAnimation(Motion.select) { model.discipline = value } } label: { label }.buttonStyle(.borderedProminent)
                .accessibilityIdentifier("issue-edit-discipline-\(value.rawValue)")
        } else {
            Button { withAnimation(Motion.select) { model.discipline = value } } label: { label }.buttonStyle(.bordered)
                .accessibilityIdentifier("issue-edit-discipline-\(value.rawValue)")
        }
    }

    // MARK: - 習熟度

    @ViewBuilder private var masterySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("習熟度", bundle: .module)
                .font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                masteryButton(Text(MasteryLevel.solo.displayName), value: .solo)
                masteryButton(Text(MasteryLevel.drill.displayName), value: .drill)
                masteryButton(Text(MasteryLevel.pattern.displayName), value: .pattern)
                masteryButton(Text(MasteryLevel.match.displayName), value: .match)
            }
            .font(.footnote)
        }
    }

    @ViewBuilder private func masteryButton(_ label: Text, value: MasteryLevel) -> some View {
        if model.masteryLevel == value {
            Button { withAnimation(Motion.select) { model.masteryLevel = value } } label: { label }.buttonStyle(.borderedProminent)
                .accessibilityIdentifier("issue-edit-mastery-\(value.rawValue)")
        } else {
            Button { withAnimation(Motion.select) { model.masteryLevel = value } } label: { label }.buttonStyle(.bordered)
                .accessibilityIdentifier("issue-edit-mastery-\(value.rawValue)")
        }
    }

    // MARK: - 影響度 / コスト

    @ViewBuilder private var impactSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("影響度(任意)", bundle: .module)
                .font(.headline)
            HStack(spacing: 8) {
                scaleButton(ScaleLabel.impact(1), isSelected: model.impact == 1) { model.toggleImpact(1) }
                    .accessibilityIdentifier("issue-edit-impact-1")
                scaleButton(ScaleLabel.impact(2), isSelected: model.impact == 2) { model.toggleImpact(2) }
                    .accessibilityIdentifier("issue-edit-impact-2")
                scaleButton(ScaleLabel.impact(3), isSelected: model.impact == 3) { model.toggleImpact(3) }
                    .accessibilityIdentifier("issue-edit-impact-3")
            }
            Text("試合の失点に直結するか", bundle: .module)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var costSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("習得コスト(任意)", bundle: .module)
                .font(.headline)
            HStack(spacing: 8) {
                scaleButton(ScaleLabel.cost(1), isSelected: model.cost == 1) { model.toggleCost(1) }
                    .accessibilityIdentifier("issue-edit-cost-1")
                scaleButton(ScaleLabel.cost(2), isSelected: model.cost == 2) { model.toggleCost(2) }
                    .accessibilityIdentifier("issue-edit-cost-2")
                scaleButton(ScaleLabel.cost(3), isSelected: model.cost == 3) { model.toggleCost(3) }
                    .accessibilityIdentifier("issue-edit-cost-3")
            }
            Text("直るまでの時間", bundle: .module)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private func scaleButton(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        if isSelected {
            Button(action: { withAnimation(Motion.select) { action() } }) { Text(verbatim: label) }.buttonStyle(.borderedProminent)
        } else {
            Button(action: { withAnimation(Motion.select) { action() } }) { Text(verbatim: label) }.buttonStyle(.bordered)
        }
    }

    // MARK: - タグ

    @ViewBuilder private var tagSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("タグ(任意)", bundle: .module)
                .font(.headline)
            ForEach(model.tags) { tag in
                HStack {
                    Text(tag.name)
                        .font(.footnote)
                    Spacer()
                    Button {
                        model.removeTag(tag)
                    } label: {
                        Text("外す", bundle: .module)
                            .font(.footnote)
                    }
                    .accessibilityIdentifier("issue-edit-tag-remove-\(tag.id)")
                }
            }
            HStack(spacing: 8) {
                TextField(text: $model.tagDraft) {
                    Text("ショット種別など", bundle: .module)
                }
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("issue-edit-tag-field")
                Button {
                    model.addTag()
                } label: {
                    Text("追加", bundle: .module)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("issue-edit-tag-add")
            }
        }
    }
}
