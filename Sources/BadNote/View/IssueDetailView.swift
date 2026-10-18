import SwiftUI

/// 課題詳細(§7.3)。
///
/// 上から できている状態 / 習熟度 / 優先度 / もとの言葉 / 記録 / 進み方 / アクション / 属性。
/// 属性は日常で使わないのでいちばん下(「克服した」を折り返しの外に沈めない。2.2)。
///
/// **編集は右上。** 属性の折りたたみの中に置いていたが、見つからなかった(2026-10-18)。
public struct IssueDetailView: View {
    @State private var model: IssueDetailModel
    @State private var isShowingAttributes = false

    public init(issueID: Int64) {
        _model = State(initialValue: IssueDetailModel(issueID: issueID))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if model.isMissing {
                    deletedNotice
                } else if let errorText = model.errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                if let issue = model.issue {
                    doneFormSection(issue)
                    masterySection(issue)
                    tierSection(issue)
                    coachWordsSection(issue)
                    recordSection(issue)
                    progressSection
                    actionSection(issue)
                    attributesSection(issue)
                }
            }
            .padding()
        }
        // タイトルは「課題」ではなく課題名そのもの。画面でいちばん大きい文字は
        // 中身のある言葉にする(tasks.md 1.2)
        .navigationTitle(Text(model.issue?.displayTitle ?? ""))
        #if os(iOS) || os(Android)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        // **編集はここに置く**(2026-10-18)。それまでは画面のいちばん下、
        // 「種目や優先度を見る」を開いた中にだけあった —— 畳まれていて、
        // ラベルからは編集できると読めず、**どこにあるか分からない**状態だった。
        // 大会詳細も右上から編集に入る。詳細画面の編集は右上で揃える
        .toolbar {
            if let issue = model.issue {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        IssueEditView(issueID: issue.id)
                    } label: {
                        Text("編集", bundle: .module)
                    }
                    .accessibilityIdentifier("issue-detail-edit")
                }
            }
        }
        // 重点が 3 枠埋まっているとき。一覧・ホームと同じ問いにする(§7.4)
        .confirmationDialog(Text("どれと入れ替えますか?", bundle: .module),
                            isPresented: $model.isShowingSwap,
                            titleVisibility: .visible) {
            ForEach(model.swapCandidates) { candidate in
                Button {
                    model.confirmSwap(with: candidate)
                } label: {
                    Text(candidate.displayTitle)
                }
            }
            Button(role: .cancel) {
                model.cancelSwap()
            } label: {
                Text("やめる", bundle: .module)
            }
        }
        .onAppear {
            model.load()
        }
    }

    // MARK: - 削除したあと(2026-10-19)

    /// 編集画面で削除すると、ここへ戻ってくる。中身はもう無い。
    ///
    /// **自動では閉じない。** `onAppear` でも `onChange` でも `dismiss()` を呼ぶと
    /// 画面を開いた瞬間にメインスレッドが止まった(2026-10-19 に 3 度踏んだ)。
    /// 本人が押して戻る形にすれば、同じ結果をもっと確実に出せる。
    @ViewBuilder private var deletedNotice: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("この課題は削除しました", bundle: .module)
                .font(.headline)
            Text("左上の「課題」から一覧に戻れます", bundle: .module)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("issue-detail-back-to-list")
        }
        .padding(.top, 24)
    }

    // MARK: - 1. できている状態(最上部に大きく)

    @ViewBuilder private func doneFormSection(_ issue: Issue) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(issue.displayTitle)
                .font(.title2)
            HStack(spacing: 8) {
                // 今どこにいるか。**重点のときだけ出す**(1.5)——「次にやる」「いつか」まで
                // 出すと全部の課題にバッジが付いて、目印としての意味が無くなる。
                // 層を変える 3 つのボタンは習熟度の下にある
                if issue.tier == Tier.focus {
                    Badge(label: Text("今週の重点", bundle: .module), tint: Palette.accent)
                }
                if issue.isFrequentlyResurfacing {
                    // §7.3 よく戻ってくる課題。弱点の本質を示す情報として出す
                    Badge(label: Text("よく戻ってくる課題", bundle: .module))
                }
                // 影響度 × コストの目印(§3.4)。「属性を見る」の奥に隠さない
                if let hint = PriorityHint.forIssue(impact: issue.impact, cost: issue.cost, tier: issue.tier) {
                    Badge(label: Text(hint.displayName), tint: hint.tint)
                }
            }
            metaLine(issue)
        }
    }

    // MARK: - 2. 習熟度(横 4 分割のバー)

    @ViewBuilder private func masterySection(_ issue: Issue) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("習熟度", bundle: .module)
                .font(.headline)
            // ●○ の文字をやめ、進み具合の部品にする(2.2)。埋まった数 = 現在のレベル
            HStack(spacing: 4) {
                ForEach(MasteryLevel.allCases, id: \.rawValue) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(level.rawValue <= issue.masteryLevel.rawValue ? Palette.accent : Palette.surfaceRaised)
                        .frame(height: 8)
                }
            }
            .accessibilityLabel(Text("習熟度", bundle: .module))
            .accessibilityValue(Text(verbatim: "\(issue.masteryLevel.rawValue)/4 \(issue.masteryLevel.displayName)"))
            Text(issue.masteryLevel.displayName)
                .font(.body)
            // §3.2 いまどこにいるか。**連続回数は出さない**(§5.3)——
            // 数字を出すと途切れた瞬間に 0 に落ち、実装しないと決めたストリークになる
            if let standing = model.standing, issue.status != IssueStatus.archived {
                Text(standing.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("issue-detail-standing")
            }
            // 上げる / 下げるはバーのすぐ下に並べる(文言が現在地に依存するので離さない)。
            // **どちらも控えめにする** —— §3.2 は「自動で上げない。done 3 回で 1 度だけ提案する」
            // 設計なので、手動昇格を画面で最も目立つボタンにすると提案の意味が薄れる(1.5)
            HStack(spacing: 8) {
                if let next = model.nextLevel {
                    Button {
                        // バーの伸びは速く動かす(5.1)
                        withAnimation(Motion.select) {
                            model.raiseLevel()
                        }
                    } label: {
                        Text(verbatim: "「\(next.displayName)」に上げる")
                    }
                    .buttonStyle(.bordered)
                    .font(.footnote)
                    .accessibilityIdentifier("issue-detail-raise")
                }
                if issue.masteryLevel != MasteryLevel.solo && !model.isArchived {
                    Button {
                        withAnimation(Motion.select) {
                            model.lowerLevel()
                        }
                    } label: {
                        Text("1 つ下げる", bundle: .module)
                    }
                    .buttonStyle(.bordered)
                    .font(.footnote)
                    .accessibilityIdentifier("issue-detail-lower")
                }
            }
        }
    }

    // MARK: - 2.5 優先度の層(2026-10-18 に足した)

    /// どの層に置くかを、この画面で決められるようにする。
    ///
    /// それまで層は一覧の長押しドラッグとスワイプ、ホームの 3 択からしか変えられず、
    /// 詳細では折りたたみの中に**読むだけ**で出ていた。
    /// 1 件を開いて「今週やるか」を決める画面なので、ここに無いのはおかしい。
    ///
    /// 見た目は練習ログの「種類」と同じ —— 今の層が塗りつぶし、残りは枠線。
    /// **アーカイブ済みのときは出さない**(層を持たない)。
    @ViewBuilder private func tierSection(_ issue: Issue) -> some View {
        if !model.isArchived {
            VStack(alignment: .leading, spacing: 8) {
                Text("優先度", bundle: .module)
                    .font(.headline)
                HStack(spacing: 8) {
                    tierButton(Tier.focus, current: issue.tier)
                    tierButton(Tier.next, current: issue.tier)
                    tierButton(Tier.someday, current: issue.tier)
                }
                // §5.3 枠の残りは数えない。**埋まっていれば押したときに聞く**ので、
                // ここに「あと N 枠」を出すと押す前から数を数えさせることになる
                Text("今週の重点は 3 件までです", bundle: .module)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private func tierButton(_ tier: Tier, current: Tier) -> some View {
        if tier == current {
            Button {
            } label: {
                Text(verbatim: tierName(tier))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .font(.footnote)
            .accessibilityIdentifier("issue-detail-tier-\(tier.rawValue)")
        } else {
            Button {
                withAnimation(Motion.select) {
                    model.move(to: tier)
                }
            } label: {
                Text(verbatim: tierName(tier))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .font(.footnote)
            .accessibilityIdentifier("issue-detail-tier-\(tier.rawValue)")
        }
    }

    // MARK: - 3. もとの言葉(引用の見た目)

    /// **言い換えを持っている課題にだけ出す**(2026-08-26)。
    ///
    /// 持っていない課題では `displayTitle` が原文そのものなので、引用すると
    /// 画面の上の見出しと同じ文が 2 度出る(ナビゲーションタイトルと合わせて 3 度)。
    /// 追加画面を 1 欄にしてから、言い換えを持たない課題のほうが多い。
    /// コーチ名と日付は引用が無くても要るので、見出しの直下(`doneFormSection`)に移した。
    @ViewBuilder private func coachWordsSection(_ issue: Issue) -> some View {
        if issue.hasDoneForm {
            VStack(alignment: .leading, spacing: 8) {
                Text("もとの言葉", bundle: .module)
                    .font(.headline)
                Card {
                    Text(issue.coachWords)
                }
            }
        }
    }

    /// コーチ名と書いた日。**課題そのものの情報**なので、引用の有無に関わらず出す。
    @ViewBuilder private func metaLine(_ issue: Issue) -> some View {
        HStack(spacing: 8) {
            if let coachName = issue.coachName, !coachName.isEmpty {
                Text(coachName)
            }
            Text(DateText.day(issue.createdAt))
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    // MARK: - 4. 記録

    @ViewBuilder private func recordSection(_ issue: Issue) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("記録", bundle: .module)
                .font(.headline)
            // 数字が主役の場所なので面に載せ、積み上げ画面と同じ形にする(2.2)
            Card {
                HStack(spacing: 12) {
                    StatItem(value: timeValue(model.totalMinutes),
                             unit: timeUnit(model.totalMinutes),
                             label: Text("累計時間", bundle: .module))
                    StatItem(value: model.focusCount,
                             unit: Text("回", bundle: .module),
                             label: Text("重点にした", bundle: .module))
                    StatItem(value: issue.resurfaceCount,
                             unit: Text("回", bundle: .module),
                             label: Text("再浮上", bundle: .module))
                }
            }
        }
    }

    /// 60 分以上は時間で、未満は分で出す(値と単位に分ける。形は `StatItem`)。
    private func timeValue(_ minutes: Int) -> Int {
        return minutes >= 60 ? minutes / 60 : minutes
    }

    private func timeUnit(_ minutes: Int) -> Text {
        return minutes >= 60 ? Text("時間", bundle: .module) : Text("分", bundle: .module)
    }

    // MARK: - 5. 進み方(色分けした点。文字にしない)

    @ViewBuilder private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("進み方", bundle: .module)
                .font(.headline)
            if model.progress.isEmpty {
                // 記録が増えるのを待つだけの場所。次の 1 手は置かない(2.4)
                EmptyStateView(message: Text("まだ記録がありません", bundle: .module)) {
                    EmptyView()
                }
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        // **`ForEach(0..<count)` にしない**(2026-10-19 に落ちた)。
                        // 範囲をそのまま渡すと SwiftUI は件数が変わらない前提で持ち、
                        // 件数が減った瞬間に古い番号で配列を引いて落ちる。
                        // 課題を削除して記録を空にしたときに踏んだ
                        ForEach(Array(0..<model.progress.count), id: \.self) { index in
                            progressMark(model.progress[index])
                        }
                    }
                }
                // 点の列は VoiceOver に伝わらないので、まとめて読み上げる(6.1)
                .accessibilityLabel(Text("進み方", bundle: .module))
                .accessibilityValue(Text(verbatim: progressSummary()))
                // 目で見る人にも意味が分かるように(読み上げには要約があるので隠す)
                progressLegend
                    .accessibilityHidden(true)
            }
        }
    }

    /// 「できた2回、近づいた1回 …」。VoiceOver 用の要約。0 回の区分は読まない。
    private func progressSummary() -> String {
        var done = 0
        var closer = 0
        var next = 0
        var blank = 0
        for result in model.progress {
            switch result {
            case .done: done += 1
            case .closer: closer += 1
            case .next: next += 1
            case nil: blank += 1
            }
        }
        var parts: [String] = []
        if done > 0 { parts.append("できた\(done)回") }
        if closer > 0 { parts.append("近づいた\(closer)回") }
        if next > 0 { parts.append("次にやる\(next)回") }
        if blank > 0 { parts.append("記録なし\(blank)回") }
        return parts.joined(separator: "、")
    }

    /// 手応えは色と形の両方で区別する(色だけに頼らない。tasks.md 1.1 / 6.1)。
    /// できた = 塗り丸 / 近づいた = 輪 / 次にやる = 四角 / 記録なし = 小さな点。
    @ViewBuilder private func progressMark(_ result: FocusResult?) -> some View {
        if let result = result {
            switch result {
            case .done:
                Circle()
                    .fill(Palette.done)
                    .frame(width: 12, height: 12)
            case .closer:
                Circle()
                    .stroke(Palette.closer, lineWidth: 3)
                    .frame(width: 9, height: 9)
                    .frame(width: 12, height: 12)
            case .next:
                RoundedRectangle(cornerRadius: 2)
                    .fill(Palette.next)
                    .frame(width: 11, height: 11)
                    .frame(width: 12, height: 12)
            }
        } else {
            Circle()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 5, height: 5)
                .frame(width: 12, height: 12)
        }
    }

    // MARK: - 7. 属性(折りたたみ。日常で使わないのでいちばん下)

    @ViewBuilder private func attributesSection(_ issue: Issue) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 導線は他の画面と同じ形(bordered + footnote)。裸の青リンクにしない(2.2)
            Button {
                isShowingAttributes = !isShowingAttributes
            } label: {
                // 優先度を上に出したので「種目や優先度を見る」から改名した(2026-10-18)。
                // 中身は種目と、入っていれば影響度・習得コスト・タグ。
                // 何が入るかは課題によって変わるので、並べ上げずに「くわしく」にした
                Text(isShowingAttributes ? "閉じる" : "くわしく見る", bundle: .module)
                    .font(.footnote)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("issue-detail-attributes")
            if isShowingAttributes {
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        attribute(Text("種目", bundle: .module), value: issue.discipline.displayName)
                        // 優先度はここに出さない(2026-10-18 に上へ出して押せるようにした)
                        if let impact = issue.impact {
                            attribute(Text("影響度", bundle: .module), value: ScaleLabel.impact(impact))
                        }
                        if let cost = issue.cost {
                            attribute(Text("習得コスト", bundle: .module), value: ScaleLabel.cost(cost))
                        }
                        if !model.tags.isEmpty {
                            attribute(Text("タグ", bundle: .module), value: tagText())
                        }
                        // 編集の導線はここに置かない(2026-10-18 に右上へ移した)。
                        // 裸の青リンクで、しかも畳まれた中にあり、見つからなかった(2.2)
                    }
                    .font(.footnote)
                }
            }
        }
    }

    @ViewBuilder private func attribute(_ label: Text, value: String) -> some View {
        HStack {
            label.foregroundStyle(.secondary)
            Spacer()
            Text(verbatim: value)
        }
    }

    private func tierName(_ tier: Tier) -> String {
        switch tier {
        case .focus: return "今週の重点"
        case .next: return "次にやる"
        case .someday: return "いつか"
        }
    }

    private func tagText() -> String {
        var names: [String] = []
        for tag in model.tags {
            names.append(tag.name)
        }
        return names.joined(separator: " / ")
    }

    // MARK: - 6. アクション(属性より上。折り返しの外に沈めない)

    @ViewBuilder private func actionSection(_ issue: Issue) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.isArchived {
                // アーカイブ済みのときだけ出す(§7.3)
                Button {
                    withAnimation(Motion.move) {
                        model.resurface()
                    }
                } label: {
                    Text("再浮上させる", bundle: .module)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("issue-detail-resurface")
                Text("レベルは 1 つ下から再開します", bundle: .module)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                // §7.3 **Lv.4 で できた が続いているときだけ強いボタンにする。**
                // それまで Lv.4 に達しても気づく手がかりが無く、克服まで届かなかった
                overcomeButton
                if let rejection = model.overcomeRejection {
                    // §7.3 Lv.3 以下で押したら理由を出す
                    Text(rejection)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    // 括弧書きで「(定着確認へ)」と書いていたが、定着確認の間隔ロジックは
                    // Phase 2 送りで存在しない。**実際に起きること**を書く(1.5)
                    Text("設定の「定着した課題」に移ります。あとで再浮上させられます", bundle: .module)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.top, 8)
    }

    /// 克服の導線。**梯子の最後**(§7.3)。
    ///
    /// 手応えが「できた」で続いていて Lv.4 なら強いボタンにする ——
    /// 評価 → 昇格 → 克服 の道筋が、ここで最後までつながる。
    @ViewBuilder private var overcomeButton: some View {
        if model.standing?.offer?.kind == MasteryOfferKind.overcome {
            Button {
                withAnimation(Motion.move) {
                    model.overcome()
                }
            } label: {
                Text("克服した", bundle: .module)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("issue-detail-overcome")
        } else {
            Button {
                withAnimation(Motion.move) {
                    model.overcome()
                }
            } label: {
                Text("克服した", bundle: .module)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("issue-detail-overcome")
        }
    }

    /// 進み方の点の凡例(§7.3)。
    ///
    /// それまでマークの意味は VoiceOver にしか無く、目で見る人には
    /// **説明のない図形が並んでいるだけ**だった。
    @ViewBuilder private var progressLegend: some View {
        HStack(spacing: 12) {
            legendItem(progressMark(FocusResult.done), "できた")
            legendItem(progressMark(FocusResult.closer), "近づいた")
            legendItem(progressMark(FocusResult.next), "次にやる")
            legendItem(progressMark(nil), "記録なし")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder private func legendItem(_ mark: some View, _ label: String) -> some View {
        HStack(spacing: 4) {
            mark
            Text(verbatim: label)
        }
    }
}
