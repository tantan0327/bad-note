#if DEBUG
import Foundation
import SkipSQL

/// ストアのスクリーンショット用のデモデータ(2026-10-11)。
///
/// **`#if DEBUG` で囲んであるのでリリースビルドには入らない。**
/// skipstone は `#if DEBUG` を常に false として変換するため、
/// **このファイルは iOS にしか存在しない**(`dev-notes.md`)。
/// Play 用に Android で撮るときは別の口が要る。
///
/// 実データのままでは撮れないので、1 タップで入れて 1 タップで消せるようにする。
/// 投入は**すべて Repository 経由**(SQL を書くのは消すときだけ。
/// 全消しのヘルパーがどこにも無いため)。
///
/// 日付は「今日」から逆算するので、いつ撮っても同じ見た目になる。
public enum DemoData {

    // MARK: - 投入

    /// デモデータを入れる。**先に全部消してから入れる**(2 回押しても増えない)。
    public static func seed(db: SQLContext, now: Date = Date()) throws {
        try DemoData.wipe(db: db)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)

        try seedVision(db: db, now: now)
        let competitions = try seedCompetitions(db: db, today: today, calendar: calendar)
        let issues = try seedIssues(db: db, today: today, calendar: calendar)
        try linkIssuesToCompetition(db: db, competitionId: competitions.target, issueIds: issues.focus)
        try seedPractices(db: db, today: today, calendar: calendar, focusIssueIds: issues.focus)
        try seedTraining(db: db, today: today, calendar: calendar)
        try seedPracticePlan(db: db, today: today, calendar: calendar)
        try seedMeta(db: db)
    }

    // MARK: - めざす姿(§7.1 ホームの主役)

    private static func seedVision(db: SQLContext, now: Date) throws {
        let repository = VisionRepository(db: db, now: { now })
        _ = try repository.save(Vision(body: "守りから攻めに切り替えるのが速い選手。終盤でも足が止まらない"))
    }

    // MARK: - 大会(§7.5)

    private struct SeededCompetitions {
        let target: Int64
    }

    /// 目標大会は **5 週間後**。2 週間以内にすると調整期に入って
    /// しばらく触れていない課題が出なくなる(§4.4)ので、そこは外す。
    private static func seedCompetitions(db: SQLContext, today: Date, calendar: Calendar) throws -> SeededCompetitions {
        let repository = CompetitionRepository(db: db, now: { today })

        var target = try repository.create(name: "県高校新人大会",
                                           eventDate: DemoData.date(today, plusDays: 35, calendar: calendar),
                                           venue: "市民体育館",
                                           entries: [CompetitionEntry(discipline: Discipline.singles, isTarget: true)])
        target.aim = "ラリーを続けて相手を動かす"
        target = try repository.update(target, entries: [CompetitionEntry(discipline: Discipline.singles, isTarget: true)])

        _ = try repository.create(name: "市民オープン",
                                  eventDate: DemoData.date(today, plusDays: 14, calendar: calendar),
                                  venue: "総合体育館",
                                  entries: [CompetitionEntry(discipline: Discipline.doubles, isTarget: false)])

        // 振り返りの書けた過去の大会(§7.5)
        let past = try repository.create(name: "地区大会",
                                         eventDate: DemoData.date(today, plusDays: -45, calendar: calendar),
                                         venue: "市民体育館",
                                         entries: [CompetitionEntry(discipline: Discipline.singles, isTarget: false)])
        try repository.saveReview(competitionId: past.id,
                                  discipline: Discipline.singles,
                                  result: "ベスト 8",
                                  wentWell: "終盤までクリアが落ちなかった",
                                  nextAction: "レシーブで面を立てる",
                                  neededResources: "ノックの相手")

        return SeededCompetitions(target: target.id)
    }

    // MARK: - 課題(§3)

    private struct SeededIssues {
        let focus: [Int64]
    }

    /// 3 層が埋まった状態を作る。**「いつか」は 12 件** ——
    /// 棚卸しの誘い(`ReviewSchedule.minimumBacklog` = 10)が出る数にしてある。
    private static func seedIssues(db: SQLContext, today: Date, calendar: Calendar) throws -> SeededIssues {
        var clock = today
        let repository = IssueRepository(db: db, now: { clock })
        let tags = TagRepository(db: db)

        let clearTag = try tags.create(name: "クリア")
        let receiveTag = try tags.create(name: "レシーブ")
        let netTag = try tags.create(name: "ネット前")
        let footworkTag = try tags.create(name: "フットワーク")

        var focusIds: [Int64] = []

        // --- 今週の重点 3 件。最近まで触っている
        clock = DemoData.date(today, plusDays: -60, calendar: calendar)
        var issue = try repository.create(coachWords: "クリアが浅い",
                                          doneForm: "ハイクリアを奥まで飛ばせている",
                                          coachName: "佐藤コーチ",
                                          discipline: Discipline.singles,
                                          masteryLevel: MasteryLevel.drill,
                                          tier: Tier.focus,
                                          sortOrder: 0,
                                          impact: 3, cost: 2,
                                          status: IssueStatus.active)
        try tags.attach(tagId: clearTag.id, to: issue.id)
        issue = try DemoData.touch(repository, issue, at: DemoData.date(today, plusDays: -3, calendar: calendar))
        focusIds.append(issue.id)

        clock = DemoData.date(today, plusDays: -90, calendar: calendar)
        issue = try repository.create(coachWords: "レシーブで面が寝ている",
                                      doneForm: "レシーブでラケット面を立てて構えられている",
                                      coachName: "佐藤コーチ",
                                      discipline: Discipline.both,
                                      masteryLevel: MasteryLevel.pattern,
                                      tier: Tier.focus,
                                      sortOrder: 1,
                                      impact: 3, cost: 2,
                                      status: IssueStatus.active)
        try tags.attach(tagId: receiveTag.id, to: issue.id)
        issue = try DemoData.touch(repository, issue, at: DemoData.date(today, plusDays: -5, calendar: calendar))
        focusIds.append(issue.id)

        clock = DemoData.date(today, plusDays: -40, calendar: calendar)
        issue = try repository.create(coachWords: "ネット前で突っ込みすぎ",
                                      doneForm: "ネット前で体が流れずに止まれている",
                                      discipline: Discipline.singles,
                                      masteryLevel: MasteryLevel.drill,
                                      tier: Tier.focus,
                                      sortOrder: 2,
                                      impact: 2, cost: 2,
                                      status: IssueStatus.active)
        try tags.attach(tagId: netTag.id, to: issue.id)
        issue = try DemoData.touch(repository, issue, at: DemoData.date(today, plusDays: -8, calendar: calendar))
        focusIds.append(issue.id)

        // --- 次にやる 5 件。目印の出る組み合わせを 2 つ混ぜる(§3.4)
        //     影響度 3 × コスト 1 =「すぐ効く」/ 影響度 3 × コスト 3 =「シーズン単位」
        let nextRows: [DemoIssue] = [
            DemoIssue(words: "サーブの後に棒立ちになる", done: "サーブ後の構えが早い",
                      level: MasteryLevel.drill, impact: 3, cost: 1, createdDaysAgo: 50, focusedDaysAgo: 20),
            DemoIssue(words: "スマッシュが同じコースばかり", done: "スマッシュのコースを打ち分けられている",
                      level: MasteryLevel.solo, impact: 3, cost: 3, createdDaysAgo: 70, focusedDaysAgo: 30),
            DemoIssue(words: "ドロップが浮く", done: "ドロップが浮かずに沈んでいる",
                      level: MasteryLevel.drill, impact: 2, cost: 2, createdDaysAgo: 35, focusedDaysAgo: 25),
            DemoIssue(words: "ロブが短い", done: "ロブを深くコントロールできている",
                      level: MasteryLevel.pattern, impact: 2, cost: 1, createdDaysAgo: 55, focusedDaysAgo: 18),
            DemoIssue(words: "最後の一歩が合わない", done: "フットワークの最後の一歩が合っている",
                      level: MasteryLevel.solo, impact: 2, cost: 3, createdDaysAgo: 65, focusedDaysAgo: 40),
        ]
        var order = 0
        for row in nextRows {
            clock = DemoData.date(today, plusDays: -row.createdDaysAgo, calendar: calendar)
            var created = try repository.create(coachWords: row.words,
                                                doneForm: row.done,
                                                discipline: Discipline.both,
                                                masteryLevel: row.level,
                                                tier: Tier.next,
                                                sortOrder: order,
                                                impact: row.impact, cost: row.cost,
                                                status: IssueStatus.active)
            if let focusedDaysAgo = row.focusedDaysAgo {
                created = try DemoData.touch(repository, created,
                                             at: DemoData.date(today, plusDays: -focusedDaysAgo, calendar: calendar))
            }
            if row.words.contains("フットワーク") || row.done.contains("フットワーク") {
                try tags.attach(tagId: footworkTag.id, to: created.id)
            }
            order += 1
        }

        // --- いつか 12 件。**多くは一度も重点にしていない**(§4.1 の「入れたきり埋もれた」)
        let somedayRows: [DemoIssue] = [
            DemoIssue(words: "バックのクリアが飛ばない", done: "バックハンドのクリアが飛んでいる", level: MasteryLevel.solo, impact: 2, cost: 3, createdDaysAgo: 150, focusedDaysAgo: nil),
            DemoIssue(words: "ヘアピンが浮く", done: "ヘアピンがネットすれすれで落ちている", level: MasteryLevel.solo, impact: 3, cost: 2, createdDaysAgo: 140, focusedDaysAgo: nil),
            DemoIssue(words: "ラウンドが安定しない", done: "ラウンド側の処理が安定している", level: MasteryLevel.solo, impact: 2, cost: 2, createdDaysAgo: 130, focusedDaysAgo: nil),
            DemoIssue(words: "相手を見ていない", done: "相手の動き出しを見てから打てている", level: MasteryLevel.solo, impact: 3, cost: 3, createdDaysAgo: 120, focusedDaysAgo: 95),
            DemoIssue(words: "連続攻撃で手打ちになる", done: "連続攻撃でも体で打てている", level: MasteryLevel.solo, impact: 2, cost: 2, createdDaysAgo: 115, focusedDaysAgo: nil),
            DemoIssue(words: "サーブレシーブで前に入れない", done: "サーブレシーブで前に入れている", level: MasteryLevel.drill, impact: 2, cost: 1, createdDaysAgo: 110, focusedDaysAgo: 80),
            DemoIssue(words: "ローテーションで前に詰められない", done: "ダブルスのローテーションで前に詰められている", level: MasteryLevel.solo, impact: 2, cost: 2, createdDaysAgo: 100, focusedDaysAgo: nil),
            DemoIssue(words: "体幹が崩れる", done: "体幹が崩れずに打てている", level: MasteryLevel.solo, impact: 1, cost: 3, createdDaysAgo: 95, focusedDaysAgo: nil),
            DemoIssue(words: "終盤に足が止まる", done: "試合終盤でも足が動いている", level: MasteryLevel.solo, impact: 3, cost: 3, createdDaysAgo: 88, focusedDaysAgo: nil),
            DemoIssue(words: "守備で正面が空く", done: "サイドバイサイドの守備で正面を空けていない", level: MasteryLevel.solo, impact: 2, cost: 2, createdDaysAgo: 80, focusedDaysAgo: nil),
            DemoIssue(words: "プッシュが合わない", done: "プッシュのタイミングが合っている", level: MasteryLevel.solo, impact: 2, cost: 1, createdDaysAgo: 75, focusedDaysAgo: nil),
            DemoIssue(words: "落下点に入るのが遅い", done: "シャトルの落下点に早く入れている", level: MasteryLevel.drill, impact: 3, cost: 2, createdDaysAgo: 72, focusedDaysAgo: 60),
        ]
        order = 0
        for row in somedayRows {
            clock = DemoData.date(today, plusDays: -row.createdDaysAgo, calendar: calendar)
            var created = try repository.create(coachWords: row.words,
                                                doneForm: row.done,
                                                discipline: Discipline.both,
                                                masteryLevel: row.level,
                                                tier: Tier.someday,
                                                sortOrder: order,
                                                impact: row.impact, cost: row.cost,
                                                status: IssueStatus.active)
            if let focusedDaysAgo = row.focusedDaysAgo {
                created = try DemoData.touch(repository, created,
                                             at: DemoData.date(today, plusDays: -focusedDaysAgo, calendar: calendar))
            }
            order += 1
        }

        // --- 定着した 3 件(積み上げの「定着した課題」に出る)
        let archivedRows = [
            "ショートサーブが浮く",
            "スマッシュレシーブが返らない",
            "一歩目が遅い",
        ]
        let archivedDone = [
            "ショートサーブが浮かずに入っている",
            "スマッシュレシーブを前に返せている",
            "構えからの一歩目が速い",
        ]
        var archivedIndex = 0
        while archivedIndex < archivedRows.count {
            clock = DemoData.date(today, plusDays: -160 + archivedIndex * 10, calendar: calendar)
            var created = try repository.create(coachWords: archivedRows[archivedIndex],
                                                doneForm: archivedDone[archivedIndex],
                                                discipline: Discipline.both,
                                                masteryLevel: MasteryLevel.match,
                                                tier: Tier.someday,
                                                sortOrder: archivedIndex,
                                                impact: 2, cost: 2,
                                                status: IssueStatus.active)
            clock = DemoData.date(today, plusDays: -30 + archivedIndex * 7, calendar: calendar)
            created.status = IssueStatus.archived
            created.archivedAt = clock
            _ = try repository.update(created)
            archivedIndex += 1
        }

        // --- 未整理 2 件(練習ログで書いた 1 行。§4.2 の置き場)
        clock = DemoData.date(today, plusDays: -2, calendar: calendar)
        _ = try repository.create(coachWords: "もっと腰を落とせと言われた")
        clock = DemoData.date(today, plusDays: -1, calendar: calendar)
        _ = try repository.create(coachWords: "相手のバック奥を使えていない")

        return SeededIssues(focus: focusIds)
    }

    /// 最後に重点にした日を入れる。
    ///
    /// **層を変えない `update` なら渡した `lastFocusedAt` がそのまま残る**
    /// (focus に入れる変更のときだけ `now()` で上書きされる)。
    private static func touch(_ repository: IssueRepository, _ issue: Issue, at date: Date) throws -> Issue {
        var edited = issue
        edited.lastFocusedAt = date
        return try repository.update(edited)
    }

    private struct DemoIssue {
        let words: String
        let done: String
        let level: MasteryLevel
        let impact: Int
        let cost: Int
        let createdDaysAgo: Int
        let focusedDaysAgo: Int?
    }

    private static func linkIssuesToCompetition(db: SQLContext, competitionId: Int64, issueIds: [Int64]) throws {
        try CompetitionRepository(db: db).setIssues(issueIds, for: competitionId)
    }

    // MARK: - 練習ログ(§7.2)

    /// 半年分。**週 3 回 × 24 週**で、積み上げが 100 時間を越える量にする。
    private static func seedPractices(db: SQLContext, today: Date, calendar: Calendar, focusIssueIds: [Int64]) throws {
        var clock = today
        let repository = PracticeRepository(db: db, now: { clock })
        let kinds = [PracticeKind.whole, PracticeKind.individual, PracticeKind.game, PracticeKind.strength]
        let minutes = [120, 90, 150, 60]
        let results: [FocusResult] = [FocusResult.done, FocusResult.closer, FocusResult.next]

        var index = 0
        var daysAgo = 170
        while daysAgo >= 1 {
            let date = DemoData.date(today, plusDays: -daysAgo, calendar: calendar)
            clock = date
            // 直近 1 か月の練習にだけ手応えを付ける(それ以前は重点が違ったという想定)
            var focus: [FocusEntry] = []
            if daysAgo <= 30 {
                var position = 0
                for issueId in focusIssueIds {
                    focus.append(FocusEntry(issueId: issueId, result: results[(index + position) % results.count]))
                    position += 1
                }
            }
            _ = try repository.create(practiceDate: date,
                                      minutes: minutes[index % minutes.count],
                                      kind: kinds[index % kinds.count],
                                      focus: focus)
            index += 1
            daysAgo -= 2
        }
    }

    // MARK: - 家トレ(§10)

    private static func seedTraining(db: SQLContext, today: Date, calendar: Calendar) throws {
        var clock = today
        let repository = TrainingRepository(db: db, now: { clock })

        let swing = try repository.createMenu(name: "素振り 50 回", minutes: 15)
        let core = try repository.createMenu(name: "体幹 10 分", minutes: 10)
        let stretch = try repository.createMenu(name: "ストレッチ", minutes: 10)
        let dash = try repository.createMenu(name: "シャトル拾いダッシュ", minutes: 10)

        // 過去 3 週間ぶん。全部は埋めない(埋まりすぎた画面は嘘くさい)
        var daysAgo = 21
        var index = 0
        while daysAgo >= 0 {
            let date = DemoData.date(today, plusDays: -daysAgo, calendar: calendar)
            clock = date
            _ = try repository.check(menuId: swing.id, on: date)
            if index % 2 == 0 {
                _ = try repository.check(menuId: core.id, on: date)
            }
            if index % 3 == 0 {
                _ = try repository.check(menuId: stretch.id, on: date)
            }
            daysAgo -= 1
            index += 1
        }
        // 今日の分は素振りだけ付けた状態にして、残りをチェックできる画面にする
        clock = today
        try repository.uncheck(menuId: core.id, on: today)
        try repository.uncheck(menuId: stretch.id, on: today)
        _ = dash
    }

    // MARK: - 練習予定日(§7.6。残り練習回数の数え元)

    private static func seedPracticePlan(db: SQLContext, today: Date, calendar: Calendar) throws {
        let repository = PracticePlanRepository(db: db, now: { today })
        var dates: [Date] = []
        var daysAhead = 1
        while daysAhead <= 35 {
            // 火・木・土のつもりで 2 日おき
            dates.append(DemoData.date(today, plusDays: daysAhead, calendar: calendar))
            daysAhead += 2
        }
        try repository.addAll(dates)
    }

    // MARK: - 設定

    /// しばらく触れていない課題を**次にホームを開いた時に評価させる**(§4.3)。
    /// 棚卸しの誘いは「いつか」が 12 件あるので、記録が無いだけで出る。
    private static func seedMeta(db: SQLContext) throws {
        let meta = AppMetaRepository(db: db)
        try meta.set("", forKey: AppMetaKey.staleLastEvaluatedAt)
        try meta.set("", forKey: AppMetaKey.reviewLastDoneAt)
        try meta.markVisionPromptShown()
    }

    // MARK: - 消す

    /// 全部消す。**撮り終えたら必ず消す。**
    ///
    /// 全消しのヘルパーが無いので、ここだけ生の SQL を書く
    /// (`Data/` の中なので永続化の層には収まっている)。
    /// 並びは子 → 親。`app_meta` は消さない —— 既定値が復活しないため、
    /// 必要な分だけ `set` で戻す。
    public static func wipe(db: SQLContext) throws {
        let tables = [
            "focus_record",
            "focus_span",
            "level_change",
            "stale_flag",
            "issue_tag",
            "issue_competition",
            "competition_entry",
            "competition_review",
            "training_log",
            "practice",
            "competition",
            "tag",
            "training_menu",
            "issue",
            "practice_plan",
            "vision",
        ]
        try db.transaction {
            for table in tables {
                try db.exec(sql: "DELETE FROM " + table)
            }
        }
        let meta = AppMetaRepository(db: db)
        try meta.set("", forKey: AppMetaKey.staleLastEvaluatedAt)
        try meta.set("", forKey: AppMetaKey.reviewLastDoneAt)
    }

    // MARK: - 内部

    private static func date(_ base: Date, plusDays days: Int, calendar: Calendar) -> Date {
        return calendar.date(byAdding: Calendar.Component.day, value: days, to: base) ?? base
    }
}
#endif
