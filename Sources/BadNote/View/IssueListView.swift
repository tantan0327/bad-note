import SwiftUI

/// 課題一覧(§7.4)。
///
/// 3 層を縦に並べたセクションリスト。**タブにしない** —— 移動先が見えている必要がある。
/// 優先順位の変更は今のところタップによる層移動のみ(ドラッグとスワイプは後で足す)。
public struct IssueListView: View {
    @State private var model = IssueListModel()

    public init() {
    }

    public var body: some View {
        List {
            if let errorText = model.errorText {
                Text(errorText)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
            // 探しているときは 3 層をほどいて 1 本にする。
            // どの層にいるか思い出せないから探しているので、層に分けても助けにならない
            if model.isSearching {
                searchSection
            }
            // 使い始めは 3 層の見出しと空行だけが並ぶ。絞り込む相手も並べる行も無いので、
            // ホーム・大会・家トレと同じく**次の 1 手だけ**を出す
            if !model.isSearching && model.isEmpty {
                Section {
                    EmptyStateView(icon: "checklist",
                                   message: Text("まだ課題がありません。コーチに言われたことや、試合で気づいたことを 1 行で書きます", bundle: .module)) {
                        NavigationLink {
                            IssueEditView()
                        } label: {
                            Text("課題を書く", bundle: .module)
                                .font(.footnote)
                        }
                        // 家トレの空状態と同じ強さ。タブを開いて最初に押す 1 つ
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("issues-empty-add")
                    }
                }
            }
            if !model.isSearching && !model.isEmpty {
                Section {
                    filterRow
                }
            }
            // §7.4 層をまたぐドラッグのため、3 層を 1 つの ForEach に畳んでいる
            if !model.isSearching && !model.isEmpty {
                ForEach(model.rows) { row in
                    if row.isHeader {
                        headerRow(row.tier)
                    } else if row.isPlaceholder {
                        emptyRow
                    } else if row.isSlot {
                        slotRow
                    } else if let issue = row.issue {
                        self.row(issue)
                    }
                }
                .onMove { offsets, toOffset in
                    // 層の移動はゆっくり(5.1)。どこへ動いたか目で追えるように
                    withAnimation(Motion.move) {
                        model.moveRows(from: Array(offsets), to: toOffset)
                    }
                }
            }
            // 4.3 スワイプとドラッグは画面から見えない操作なので、言葉で常設しておく
            // (初回だけのヒントは忘れた頃に効かず、グリップはドラッグの開始点と誤解させる)。
            // **説明する行の後ろに置く**(1.10。絞り込みの直下は一等地なので明け渡した)。
            // **並べる行があるときだけ** —— 試せない操作の説明は常設しない
            if !model.isSearching && model.hasTieredIssues {
                Section {
                    // 効かない操作を案内し続けない。並び替え中は長押しが止まっている
                    if model.allowsDrag {
                        Text("行は長押しで並び替え、左右スワイプで層の上げ下げができます", bundle: .module)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("この並びでは長押しの並び替えはできません。「この並びで整理」を押すと、いまの順番を保存して並べ替えられるようになります", bundle: .module)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // 4.2 練習ログで書いた 1 行(inbox)の置き場。「書いたのに見つからない」を無くす。
            // 件数は層見出しと同じ出し方(タブのバッジにはしない §5.3)。
            // ドラッグの 1 本の ForEach には混ぜない(構造を崩すとドラッグが壊れる)
            if !model.isSearching && !model.unorganized.isEmpty {
                Section {
                    ForEach(model.unorganized) { issue in
                        NavigationLink {
                            IssueDetailView(issueID: issue.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(issue.displayTitle)
                                    .font(.body)
                                Text(DateText.day(issue.createdAt))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityIdentifier("issue-inbox-row-\(issue.id)")
                    }
                    NavigationLink {
                        InboxTriageView()
                    } label: {
                        Text("整理する", bundle: .module)
                            .font(.footnote)
                    }
                    .accessibilityIdentifier("issue-list-triage-link")
                } header: {
                    HStack {
                        Text("未整理", bundle: .module)
                        Spacer()
                        Text(verbatim: "\(model.unorganized.count)件")
                    }
                }
            }
            // 重点も候補も無いと、組み替え画面は「まだ選んでいません」+「候補がありません」の
            // 空の画面になる。**行っても何もできない導線は出さない**(1.9)
            if !model.isSearching && FocusBoard.canReshuffle(focusCount: model.focus.count,
                                                             candidateCount: model.next.count + model.someday.count) {
                Section {
                    NavigationLink {
                        FocusReshuffleView()
                    } label: {
                        Text("今週の重点を組み替える", bundle: .module)
                            .font(.footnote)
                    }
                    .accessibilityIdentifier("issues-reshuffle")
                }
            }
        }
        .navigationTitle(Text("課題", bundle: .module))
        // 課題が増えると、種目 / 習熟度 / タグの絞り込みだけでは 1 件に辿り着けない。
        // **言葉から引く**入口を足す(§7.4)
        .searchable(text: $model.searchText,
                    prompt: Text("課題を探す", bundle: .module))
        // 5.2 層の移動(スワイプ・ドラッグ)の触覚。トリガーは操作回数(読み込みでは鳴らない)
        .sensoryFeedback(SensoryFeedback.impact, trigger: model.moveCount)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    IssueEditView()
                } label: {
                    Text("追加", bundle: .module)
                }
                .accessibilityIdentifier("issues-add")
            }
            // §5.3 未整理の**件数**はバッジで出さない。導線だけ置く。
            // ただし 0 件のときは押しても「整理する課題はありません」に着くだけなので出さない(1.9)
            if !model.unorganized.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        InboxTriageView()
                    } label: {
                        Text("整理", bundle: .module)
                    }
                    .accessibilityIdentifier("issues-triage")
                }
            }
        }
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

    /// 検索の結果。**層をほどいて 1 本**にし、行ごとに居場所のバッジを添える。
    ///
    /// **ここでは動かさない。** 探す場所と動かす場所を分ける ——
    /// スワイプもドラッグも持たせず、タップして詳細で決める。
    @ViewBuilder private var searchSection: some View {
        if model.searchResults.isEmpty {
            Section {
                EmptyStateView(message: Text("見つかりませんでした", bundle: .module)) {
                    EmptyView()
                }
            }
        } else {
            Section {
                ForEach(model.searchResults) { issue in
                    NavigationLink {
                        IssueDetailView(issueID: issue.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(issue.displayTitle)
                                .font(.body)
                            HStack(spacing: 8) {
                                Badge(label: Text(placeName(issue)))
                                MasteryIndicator(level: issue.masteryLevel)
                            }
                        }
                    }
                    .accessibilityIdentifier("issue-search-row-\(issue.id)")
                }
            } header: {
                Text(verbatim: "\(model.searchResults.count)件")
            }
        }
    }

    /// 検索結果の行に添える居場所。
    /// **未整理は層ではなく「未整理」と出す** —— まだ層を決めていないので、
    /// 既定値の「いつか」を見せると決めたことになってしまう。
    private func placeName(_ issue: Issue) -> String {
        if issue.status == IssueStatus.inbox {
            return "未整理"
        }
        return tierName(issue.tier)
    }

    /// §7.4 上部に 1 行。並び替え / 種目 / 習熟度 / ショットタグ。**既定はフィルタなし。**
    ///
    /// **並び替えを先頭に置く。** 課題が増えたときに最初に手が伸びるのがここで、
    /// タグのメニューは候補が無いと消えるため、位置が動かない左端に置く。
    @ViewBuilder private var filterRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                Menu {
                    ForEach(IssueSortOrder.allCases, id: \.rawValue) { value in
                        Button {
                            model.selectSortOrder(value)
                        } label: {
                            Text(value.displayName)
                        }
                    }
                } label: {
                    filterLabel(model.selectedSortName(), placeholder: Text("並び替え", bundle: .module))
                }
                .accessibilityIdentifier("issues-sort")

                // **見えている順を保存順にする。** これが無いと、優先順に「見る」ことは
                // できても「整理する」ことができない(並び替え中はドラッグが止まるため)
                if !model.allowsDrag && !model.isSearching {
                    Button {
                        withAnimation(Motion.move) {
                            model.commitDisplayedOrder()
                        }
                    } label: {
                        Text("この並びで整理", bundle: .module)
                    }
                    .buttonStyle(.borderedProminent)
                    .font(.footnote)
                    .accessibilityIdentifier("issues-commit-order")
                }

                Menu {
                    Button {
                        model.selectDiscipline(nil)
                    } label: {
                        Text("すべての種目", bundle: .module)
                    }
                    ForEach(Discipline.allCases, id: \.rawValue) { value in
                        Button {
                            model.selectDiscipline(value)
                        } label: {
                            Text(value.displayName)
                        }
                    }
                } label: {
                    filterLabel(model.discipline?.displayName, placeholder: Text("種目", bundle: .module))
                }
                .accessibilityIdentifier("issues-filter-discipline")

                Menu {
                    Button {
                        model.selectMasteryLevel(nil)
                    } label: {
                        Text("すべての習熟度", bundle: .module)
                    }
                    ForEach(MasteryLevel.allCases, id: \.rawValue) { value in
                        Button {
                            model.selectMasteryLevel(value)
                        } label: {
                            Text(value.displayName)
                        }
                    }
                } label: {
                    filterLabel(model.masteryLevel?.displayName, placeholder: Text("習熟度", bundle: .module))
                }
                .accessibilityIdentifier("issues-filter-mastery")

                if !model.availableTags.isEmpty {
                    Menu {
                        Button {
                            model.selectTag(nil)
                        } label: {
                            Text("すべてのタグ", bundle: .module)
                        }
                        ForEach(model.availableTags) { tag in
                            Button {
                                model.selectTag(tag.id)
                            } label: {
                                Text(tag.name)
                            }
                        }
                    } label: {
                        filterLabel(model.selectedTagName(), placeholder: Text("タグ", bundle: .module))
                    }
                }

                if model.isFiltering {
                    Button {
                        model.clearFilters()
                    } label: {
                        Text("解除", bundle: .module)
                    }
                    .buttonStyle(.bordered)
                    .font(.footnote)
                }
            }
        }
    }

    @ViewBuilder private func filterLabel(_ selected: String?, placeholder: Text) -> some View {
        if let selected = selected {
            Text(verbatim: selected)
                .font(.footnote)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Palette.accent.opacity(0.2))
                .cornerRadius(16)
        } else {
            placeholder
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Palette.surface)
                .cornerRadius(16)
        }
    }

    /// 空の層の行。**`moveDisabled` を付けない** ——
    /// これがドラッグの落とし先になる(付けると空の層に移動できなくなる)。
    @ViewBuilder private var emptyRow: some View {
        Text("まだありません", bundle: .module)
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    /// 重点の空き枠(1.10)。**ホームと同じ言葉・同じ導線**にして、
    /// 「同じ概念の見せ方が 2 通りある」状態を無くす。
    /// `moveDisabled` を付けない —— ここがドラッグで運ぶ的になる。
    @ViewBuilder private var slotRow: some View {
        HStack {
            Text("空き枠", bundle: .module)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            // 外す相手も候補もいないのに「選ぶ」を出すと空振りになる(1.9 の判断を再利用)
            if FocusBoard.canReshuffle(focusCount: model.focus.count,
                                       candidateCount: model.next.count + model.someday.count) {
                NavigationLink {
                    FocusReshuffleView()
                } label: {
                    Text("選ぶ", bundle: .module)
                        .font(.footnote)
                }
                .accessibilityIdentifier("issues-slot-pick")
            }
        }
    }

    /// 層の見出し。ドラッグの落下位置を決める区切りでもあるので、行として並べる。
    ///
    /// **押すと畳める**(2026-10-12)。溜まった「いつか」が開いたまま並ぶと、
    /// 一覧が 1 本の長いリストになって上の 2 層が視界から消える。
    /// 件数は畳んでいても出すので、隠れた数は分かる。
    @ViewBuilder private func headerRow(_ tier: Tier) -> some View {
        Button {
            withAnimation(Motion.move) {
                model.toggleCollapse(tier)
            }
        } label: {
            HStack {
                Text(tierName(tier))
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text(verbatim: tier == Tier.focus
                     ? "\(model.count(of: tier))/\(model.focusCapacity)"
                     : "\(model.count(of: tier))件")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(verbatim: model.isCollapsed(tier) ? "＋" : "−")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
        .moveDisabled(true)
        .accessibilityIdentifier("issues-tier-\(tier.rawValue)")
        .accessibilityValue(model.isCollapsed(tier)
                            ? Text("畳んでいます", bundle: .module)
                            : Text("開いています", bundle: .module))
    }

    private func tierName(_ tier: Tier) -> String {
        switch tier {
        case .focus: return "今週の重点"
        case .next: return "次にやる"
        case .someday: return "いつか"
        }
    }

    /// §7.4 一覧を眺めながら次々に仕分ける用途に最速なので、スワイプで 1 段ずつ動かす。
    /// 右スワイプ(`.leading`)で上げ、左スワイプ(`.trailing`)で下げる。
    @ViewBuilder private func row(_ issue: Issue) -> some View {
        NavigationLink {
            IssueDetailView(issueID: issue.id)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(issue.displayTitle)
                    .font(.body)
                HStack(spacing: 8) {
                    // 文字だけにしない。ミニバーで進み具合が見える(2.3)
                    MasteryIndicator(level: issue.masteryLevel)
                    // 影響度 × コストの目印(§3.4)。付くのは影響度が大きい課題だけ
                    if let hint = PriorityHint.forIssue(impact: issue.impact, cost: issue.cost, tier: issue.tier) {
                        Badge(label: Text(hint.displayName), tint: hint.tint)
                    }
                    // **並び替えの基準は行にも出す**(2026-10-12)。
                    // 放置が長い順で眺めているのに、どれくらい放置したのかが
                    // 行から読めないと、並びを信じるしかなくなる。
                    // 常設しないのは、他の並びでは判断材料にならないため
                    if model.sortOrder == IssueSortOrder.idle {
                        Text(DateText.day(issue.lastFocusedAt ?? issue.createdAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .accessibilityIdentifier("issue-row-\(issue.id)")
        // 見えている順と保存順が違うときは落とす先が読めない(§3.3)。
        // スワイプの上げ下げは位置に依存しないので、そのまま使える
        .moveDisabled(!model.allowsDrag)
        .swipeActions(edge: .leading) {
            if issue.tier.higher != nil {
                Button {
                    withAnimation(Motion.move) {
                        model.promote(issue)
                    }
                } label: {
                    Text("上げる", bundle: .module)
                }
            }
        }
        .swipeActions(edge: .trailing) {
            if issue.tier.lower != nil {
                Button {
                    withAnimation(Motion.move) {
                        model.demote(issue)
                    }
                } label: {
                    Text("下げる", bundle: .module)
                }
            }
        }
    }

}
