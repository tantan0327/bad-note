# タスク

`spec.md` のうち、何ができていて何が残っているか。

最終更新: 2026-08-25

**Phase 1 の機能・デザインの土台・磨き込み(家トレ / 迷わせない工夫 / 動きと手触り /
品質)はすべて完了し、実機で確認済み。** 決めごとは「現状」の**デザインの決めごと**と
`spec.md` に集約してある(完了したタスクの一覧はここでは持たない。履歴は git log)。

**次にやること: §1 の UI/UX 改善 → §2 の配信**(スクリーンショットは UI を直してから撮る。
先に撮ると古い画面で申請することになる)。

---

## 現状

テスト 534 本(JUnit 535)。iOS / Android(Robolectric)の両方でパス。
両プラットフォームでビルド成功。`skip verify`(ストアのメタデータ)も通る。

**データ層** — Repository は 8 つ(`Issue` / `Practice` / `Competition` / `Vision` / `Tag` /
`Training` / `Stats` / `Export`)。加えて `AppMeta` / `StaleFlag` / `StaleEvaluator`。
**画面に出す累計は `StatsRepository.totalMinutes` だけから取る**(§10.3。
`PracticeRepository` 直では家トレの分が落ちる)。

**テーブル** — マイグレーション 11 本で §6 / §10.4 / §7.5(大会のねらい)のテーブルと列は
すべて作成済み。**足すときは `migrations` の末尾に 1 要素。既存の要素は書き換えない。**

**ロジック**(すべて純粋関数・テスト済み)

| 型 | 仕様 |
|---|---|
| `PracticeForecast` | §5.2 残り練習回数 |
| `LevelUpSuggestion` | §3.2 done 3 回連続の提案(1 度だけ) |
| `FocusBoard` | §7.4 重点 3 枠、層の移動と入れ替え |
| `StaleEvaluation` | §4.2 stale 判定(3 条件と優先順位) |
| `StaleSchedule` | §4.3 週 1 回の実行ゲート |
| `AdjustmentPeriod` | §4.4 調整期(最も近い目標大会で全体を 1 つに) |
| `HomeEmphasis` | §5.1 8 週間での表示切り替え(種目ごと) |
| `MonthRange` | 今月の集計期間 |
| `VisionPrompt` | §7.1 めざす姿の促し(初回は促さず、数回使った後に 1 度だけ) |
| `CompetitionFeasibility` | §7.5「この大会では厳しいかもしれません」の判定 |
| `TierLayout` | §7.4 長押しドラッグの落下位置から層と位置を逆算 |
| `NotificationPlan` | §8 いつ何を通知するか(1 日 1 通の絞り込み含む) |

**画面** — ホーム(§7.1)/ 練習ログ入力(§7.2)/ 課題一覧(§7.4 の一部)/ 課題の登録・編集(§3)/
インボックス整理 / めざす姿の編集(§7.1、テキストのみ)/ 大会一覧・登録(§7.5 の一部)/
課題詳細(§7.3)/ 週次の組み替えモード(§7.4)/ アーカイブ(§7.4)/ 大会詳細・振り返り(§7.5)/
通知設定(§8)/ 家トレ・メニュー管理(§10)/ 積み上げ(ホームから開く)/
データの書き出し(§11、設定から)。

**まだ無いもの** — なし(Phase 1 + 新機能はすべて実装済み)。

**原文の欄のラベル**(2026-08-22、実使用より) — **画面ごとに変えている。**

- 練習ログ入力(§7.2): **「追加する課題」** —— これから何が起きるか(課題が増える)を伝える
- 課題詳細 / 登録・編集 / インボックス整理: **「もとの言葉」** ——
  その文が何なのか(原文)を伝える。**基本そのままだが、誤入力は課題の編集から直せる**
  (2026-08-24 決定。それまでの「編集しない」を緩めた)

4 画面で揃える前提で「コーチの言葉」→「気づいたこと」と直したが、
**画面ごとに伝えるべきことが違う**と気づいて分けた。
用語集の見出し語は「もとの言葉」。**識別子 `coachWords` は変えていない**(説明だけ広げた)。

**リンク色の扱い**(2026-08-22) — `NavigationLink` / `Button` のラベルは
**全体に accent 色が乗る**。本文を置くラベルには `.foregroundStyle(.primary)` を当てること。
当てないと課題のタイトルやめざす姿の本文が青字になり、`List` の中と外で色が変わる。
押す先がある導線(「編集する」など)は青のままにしている。

### デザインの決めごと(2026-08-22。両 OS × ライト / ダークで実機確認済み)

**色**:

- **ブランド色はインディゴ**(light `#5C6BC0` / dark `#7986CB`)。`AccentColor` は
  `Darwin/Assets.xcassets` と `Sources/BadNote/Resources/Module.xcassets` の 2 か所にあり、
  **値は同じに保つ**(Android に効くのは Module 側だけ。開発メモ「色は asset catalog 経由…」参照)
- **色は `View/Palette.swift` の 6 トークンから取る** —— `accent` / `surface` / `surfaceRaised` /
  `done` / `closer` / `next`。実体は `Module.xcassets` の colorset(light / dark の 2 値)なので、
  色替えは JSON を直すだけで両プラットフォームに効く。**View で色を直書きしない**
- **手応えは色 + 形** —— できた = 塗り丸(緑)/ 近づいた = 輪(琥珀)/ 次にやる = 四角(青)/
  記録なし = 小さな灰点(課題詳細の進み方)。色だけに頼らない

**文字の段階**(役割 → フォント。新しい文字はこの表から選ぶ):

| 役割 | フォント | 例 |
|---|---|---|
| 画面の主役(その画面の固有名) | `.title2` | 課題名(できている状態)、大会名、めざす姿の本文 |
| 画面の主数字 | `.system(size: 34, weight: .semibold)` | 残り日数(ホーム・大会詳細) |
| セクション見出し | `.headline` | 「今週の重点」「もとの言葉」 |
| セクション内の小見出し | `.subheadline` | 振り返りの種目名 |
| 本文・一覧の行タイトル・引用 | `.body`(既定) | 課題の行、もとの言葉の原文 |
| 補足・メタ情報・小さな導線 | `.footnote` | 日付、件数、「編集する」 |
| チップ・バッジ・注釈 | `.caption` | 習熟度チップ、入力の説明文 |
| カード内の統計数字 | 22pt semibold(単位・ラベルは `.caption`) | `View/StatItem.swift`。積み上げの 2 スタット、課題詳細の記録 |

詳細画面のタイトルは**その画面の固有名**(課題名・大会名)を inline で出す。
「課題」「大会」のような中身の無い大タイトルは出さない
(`.navigationBarTitleDisplayMode` は macOS 不可 → `#if os(iOS) || os(Android)` で囲む)。
一覧系の大タイトル(課題 / 大会 / 設定など)は中身を表す言葉なのでそのまま。
例外 —— 練習時間入力の分数(52pt)は入力部品の表示で表の外。

**面と余白**(新しい面はこの 3 種類から選ぶ):

| 部品 | 形 | どこで決まるか |
|---|---|---|
| カード | 面 `Palette.surface` / 内側 12 / 角丸 8 / 幅いっぱい | `View/Card.swift`(`Card { ... }`)。強調の帯は `Card(background: Palette.surfaceRaised)` |
| バッジ(表示のみ) | `.caption` / 横 8 縦 4 / 角丸 4 / `Palette.surfaceRaised` | `View/Badge.swift`(2.3 で部品化)。押せる部品には使わない |
| ピル(押せる絞り込み) | `.footnote` / 横 12 縦 8 / 角丸 16 | 課題一覧の絞り込み行のみ |
| 行の習熟度 | ミニ 4 分割バー + `.caption` の段階名 | `View/MasteryIndicator.swift`(2.3)。課題詳細のバーの縮小版 |

- **動き** —— 選択・チェック・バーの伸縮 = `Motion.select`(easeOut 0.15)、
  行の移動・出入り・画面の切り替わり = `Motion.move`(easeInOut 0.3)。
  `View/Motion.swift` から取り、duration を直書きしない(5.1)
- **`accessibilityIdentifier` の命名**(6.1)—— kebab-case で「画面-部品(-id)」
  (`home-record` / `issue-row-3` / `practice-kind-whole`)。操作可能な View には必ず付ける
- **プラットフォーム差の線引き**(5.3、2026-08-24 決定)——
  **アプリのアイデンティティは共通トークンで揃え、OS 標準部品の見た目は各 OS に委ねる。**
  揃える側: 色(Palette)/ 文字の段階 / 面と余白(Card・Badge ほか)/ 動き(Motion)/
  アイコン(.symbolset)/ 文言。委ねる側: ツールバー・日付や時刻のピッカー・スイッチ・
  リストの作法など OS が描く部品(Skip の既定どおり)。
  **例外は「差が誤解や操作ミスを生む」場合だけ**個別に対応する(今は該当なし)
- **間隔は 4 の倍数だけ**(`4` / `8` / `12` / `16` / `20` / `24`)
- **余白は 2 段階** —— 画面の外周は `.padding()`(= 16)、カードの内側は `Card` が持つ 12
- **区切り線** —— 同じ形の行を選ぶだけの画面 = `List`(設定 / 課題一覧 / 組み替えモード /
  大会一覧 / アーカイブ / 家トレ)。役割の違うブロックが縦に並ぶ画面 = カード
  (ホーム / 課題詳細 / 大会詳細 / 練習ログ入力 / インボックス整理)

**通知**(§8)は 3 種類とも実装済み(練習前 / 大会当日の夜 / 週 1 回)。**1 日 1 通まで**で、
重なったときの優先は **大会 → stale → 練習前**。繰り返しトリガーではなく
21 日分を毎回入れ直す方式(繰り返しだと 1 日 1 通の制御ができない)。既定は off。

**課題一覧**(§7.4)は §7.4 の 3 つの方法すべてを実装済み ——
**長押しドラッグ**(層をまたぐ移動と層内の並び替え)/ **スワイプ**(右で 1 段上げ / 左で 1 段下げ)/
**週次の組み替えモード**。加えて**絞り込み行**(種目 / 習熟度 / タグ、既定はフィルタなし)。
種目の絞り込みは `both` の課題も含める(§3.5)。

ドラッグは 3 層を見出し行込みの 1 本の `ForEach` に畳んで実現している
(`onMove` はひとつの `ForEach` 内でしか働かないため)。落下位置から層と位置を求めるのは
`TierLayout`。**この構造を崩すとドラッグが壊れる。**

**タブ構成** — **ホーム / 家トレ / 課題 / 大会** の 4 つ(2026-08-22 実装)。
タブは「往復するもの」だけに絞る。家トレ(§10)は毎日開く画面なのでホームの隣。

- 練習ログ入力はホームのボタンからシート(§7.2 のヘッダーが ✕ / 保存 のモーダル)
- 課題詳細は課題一覧からプッシュ
- 設定は日常操作ではないのでホームのツールバー(歯車)。
  stale の閾値・通知時刻・アーカイブ閲覧の置き場になる

テンプレート(`WelcomeView` / `ItemListView` / `ViewModel.swift` / `Item`)は削除済み。

**アイコンは `.symbolset`**(2026-08-21)。`systemName:` / `systemImage:` の使用箇所はゼロ。
`Sources/BadNote/Resources/Icons.xcassets/` に `home` / `checklist` / `emoji_events` / `settings`
を配置し、iOS・Android の両方で同じ Material Symbols が描画されることを確認済み。
追加手順は `skip-icons` スキルのとおり。

**iOS / Android の両方で実機動作を確認済み**(2026-08-21)。
Android エミュレータ(API 34 / SQLite 3.39.2)で DB 作成・マイグレーションの適用・
週次評価の初回実行・課題の登録まで通ることを確認した。
アイコンと通知の許可ダイアログも確認済み(2026-08-25)。

---

## 1. UI/UX の改善(2026-08-25 に全画面を通しで見て洗い出した)

**優先順位は「壊れている > 入力が報われない > 摩擦 > 一貫性」の順。**
**1.1〜1.7 は完了(スクリーンショット前に直す分は全部済み)。次は 1.8 以降。**

### 1.1 目標大会が終わると、そこで止まる —— **済(2026-08-25)**

**症状**: 終了した大会の目標フラグが残るため `fetchTarget` が過去の大会を返し、
`hasTargetCompetition` が true のまま。カウントダウンのカードは出ない(過去なので)のに
空の状態の案内も出ないので、**ホームのその一帯が完全な空白になって手が止まっていた**。
しかも空の状態にあった「大会を登録する」は `Text` で**押せない飾り**だった。

**直したこと**:

- `CompetitionRepository.clearFinishedTargets(asOf:)` を新設し、ホームと大会一覧の
  読み込みで呼ぶ。過ぎた大会の `is_target` を下ろす(**当日いっぱいは目標のまま**。
  基準は今日の 0 時。エントリー種目の行は消さない)。テスト +5
- ホームのカウントダウン欄を `Card` にして「目標の大会が決まっていません」+
  「決めると、残り日数と残り練習回数が出ます」+ **押せるボタン**にした。
  手前に大会があれば「「◯◯」を目標にする」→ その大会の編集画面、
  無ければ「大会を登録する」→ 新規作成。**どの種目の目標かは本人が決める**
- `HomeModel.targetCandidate` を新設(`nextCompetition` と排他)。
  **目標が無いときは「次の大会」セクションを出さない** —— 「手前」は目標があって
  はじめて意味を持つし、同じ大会がホームに 2 回並んでしまう

### 1.2 影響度を入力させているのに、どこにも使っていない —— **済(2026-08-25)**

**症状**: `impact` は追加・整理の両方で入力させるのに、出力は課題詳細の
「属性を見る」の奥にテキストで出るだけ。**選ぶ場面(課題一覧・組み替え)に届いていなかった。**
`spec.md` §3.4 の「影響度 3 × コスト 1 にバッジ」は未実装だった。

**直したこと**:

- `PriorityHint`(純粋関数)を新設。**すぐ効く**(影響度 大 × すぐ直る)と
  **シーズン単位**(影響度 大 × シーズン単位)の 2 つだけを返す。
  影響度が大きくない課題には付けない —— **どれにも付けると目印の意味が無くなる**。
  未入力は nil(入力は任意なので欠けているのが普通)。テスト +6
- 出す場所は**選ぶ場面**: 課題一覧の行 / 組み替えの候補 / 課題詳細の見出し下
- `Badge` に `tint` を足した。**面は `surfaceRaised` のまま、意味の違いは文字色だけ**
  (面まで色を付けると一覧が騒がしくなる)。すぐ効く = accent、シーズン単位 = secondary
- **並べ替えも自動選択もしない**(アプリは解釈しない)。目印を添えるだけ

### 1.3 日付の表記が画面ごとに違う(英語が出る)—— **済(2026-08-25)**

**症状**: 家トレだけが `ja_JP` 固定で「8月24日(月)」、他の 5 画面
(大会一覧 / 大会詳細 / 課題一覧 / 課題詳細 / アーカイブ)は
`formatted(date: .abbreviated)` で**システムロケール依存**。端末が日本語以外だと
「Aug 15, 2026」と英語で出て、アプリの中で表記が混ざっていた。

**直したこと**:

- `View/DateText.swift` を新設し、**画面に出す日付は必ずここを通す**ようにした。
  `formatted(date:time:)` の使用箇所はゼロ。家トレの自前実装もここに寄せた。テスト +6
- 2 つだけ用意した:
  - `day(_:asOf:)` —— 「8月24日」。一覧やメタ情報(課題の作成日、アーカイブした日)
  - `dayWithWeekday(_:asOf:)` —— 「8月24日(月)」。**その日そのものが主役の場面**
    (家トレの見出し、大会の開催日)。大会は土日開催が多く曜日が判断材料になる
- **年は今年と違うときだけ出す**(「2027年2月20日(土)」)。常に出すと冗長で、
  出さないと去年の記録が今年のものに見える。目標大会は半年先=翌年になることが多い
- **OS が描く日付ピッカーは対象外**。各 OS の作法に委ねる決めごと
  (「デザインの決めごと」のプラットフォーム差の線引き)に従う

### 1.4 課題詳細で同じ文字列が 3 回出る —— **済(2026-08-26)**

**症状**: ナビゲーションタイトル / 画面上部の大見出し / 「もとの言葉」の引用。
「できている状態」が未記入の課題では 3 つとも同じ文字列だった。
追加画面を 1 欄にした(2026-08-25)ので、これから作る課題はすべてこの状態になる。

**直したこと**:

- `Issue.hasDoneForm` を新設(**原文とは違う**言い換えを持っているか。
  空文字も原文と同じ文字列も false)。テスト +6
- 「もとの言葉」の引用は `hasDoneForm` のときだけ出す。
  言い換えがあってはじめて「言い換え前」として意味を持つ
- **コーチ名と書いた日は引用が消えても要る**ので、見出しの直下に移した
  (課題そのものの情報であって、引用に付属する情報ではない)
- ナビゲーションタイトルと大見出しの重なりは**残す**。
  詳細画面は固有名を inline で出す決めごと(「デザインの決めごと」)で、
  スクロールしても文脈が消えない。大会詳細も同じ形

### 1.5 課題詳細でいちばん強いボタンが「レベルを上げる」—— **済(2026-08-26)**

**直したこと**:

- 「「◯◯」に上げる」を `.borderedProminent` → `.bordered`。
  **「レベルを 1 つ下げる」を画面下からバーの直下へ移し**、上げ / 下げを同じ重さで並べた
  (文言が現在地に依存するのでバーから離さない)。結果、この画面の強いボタンは
  **アーカイブ時の「再浮上させる」だけ**になった
- **「克服した(定着確認へ)」→「克服した」**。定着確認の間隔ロジックは Phase 2 送りで
  存在しないので、ラベルで約束しない。下に**実際に起きること**を書いた
  (「設定の「定着した課題」に移ります。あとで再浮上させられます」)
- **「属性を見る」→「種目や優先度を見る」**(閉じるときは「閉じる」)
- **`focus` のときだけ「今週の重点」バッジ**を見出しの下に(accent)。
  `next` / `someday` には出さない —— 全部に付けると目印の意味が無くなる
- **`quickWin` を重点の課題に出さないようにした**(`forIssue` に `tier` を追加)。
  「重点に入れるべき候補」がもう重点にいるのは矛盾する。
  `seasonLong` は重点でも出す(「間に合わないかも」は入ってからも意味がある)。テスト +3

### 1.6 大会の振り返りが空欄 4 つ —— **済(2026-08-28)**

**直したこと**:

- 見出しの下に「**結果だけでも保存できます。空のままの欄があっても構いません**」。
  大会直後に 4 つ並ぶ空欄を前に、全部埋めなくていいと先に言う
- **各欄に例を置いた**(「例: 2回戦敗退」「例: 後ろに下がる判断を先に出す」など)
- **欄ごとに 1 行 / 複数行を使い分けた** —— 「うまくいったこと」だけ `TextEditor`。
  「次にやること」は**そのまま課題の 1 行になる**ので、課題の書き方に合わせて 1 行のまま
  (全部を複数行にすると縦に伸びるだけで、書く量の目安も伝わらない)
- 「次にやることを課題にする」を**その欄が空なら押せなく**した。
  それまでは押せるのに `createIssueFromNextAction` が黙って return していて、
  押した側には成功したのか失敗したのか分からなかった

### 1.7 これからの大会が無いとき、登録の導線が無い —— **済(2026-08-28)**

**症状**: 大会一覧の空の状態は `upcoming` と `finished` の**両方が空のときだけ**出ていた。
**終わった大会だけが残っている状態**(大会が 1 つ終われば必ずこうなる)では
「終了した大会」の一覧が出るだけで、次に何をすればいいか分からなかった。1.1 と同じ穴。

**直したこと**:

- `upcoming` が空で `finished` がある場合に、**「これからの大会」の見出しつき空セクション**を
  出す(「登録すると、ホームに残り日数と残り練習回数が出ます」+「大会を登録する」)。
  位置は終了した大会の**上**で、大会があるときの並び順と同じ
- 両方空のときの全体の空状態は従来どおり

### 1.8 めざす姿に書き方の手がかりが無い

大きな空の入力欄に「なりたい選手像を書きます」だけ。課題の追加には例文を置いたのに
(2026-08-25)、いちばん抽象的で書きにくいこの画面には例が無い。
`spec.md` §1 の ✗ / ○ の例(自分の課題として書く)をそのまま使える。

### 1.9 空振りする導線

- 課題一覧の「整理」は**未整理が 0 件でも常設**。押すと「整理する課題はありません」。
  §5.3 の「件数のバッジを出さない」は守りつつ、0 件のときは出さない手はある
- 組み替えモードに**終わりの合図が無い**(戻る矢印だけ)。「組み替えを終える」を置く

### 1.10 一貫性のずれ(まとめて直す)

- **組み替えモードだけ大タイトル**。他の押し込んだ画面は inline なのに、ここだけ 2 行を占める
- **課題一覧の重点セクションに空き枠が出ない**。ホームは「空き枠 / 選ぶ」を出すのに、
  一覧は「1/3」の数字だけ。同じ概念の見せ方が 2 通りある
- **長押し / スワイプのヒントが絞り込みの直下に 2 行常設**。一等地を毎回同じ文が占める。
  折りたたむか、層の見出しの近くに寄せる
- 組み替えの候補に**判断材料が無い**(影響度・最後に触れた日・stale)。1.2 と一緒に直す

---

## 2. 配信に残っている作業

### 2.1 ストアのスクリーンショット

fastlane のテキストと設定は済み(`skip verify` が通る)。**画像だけが無い。**

- `Darwin/fastlane/screenshots/ja/N_ja.png` —— iPhone 6.7"(1290×2796)
- `Android/fastlane/metadata/android/ja-JP/images/phoneScreenshots/N_ja-JP.png`
- Play は加えて `images/icon.png`(512×512)と `featureGraphic.png`(1024×500)
- 各ストア 1 ロケールにつき最低 1 枚、最大 10 枚

手順は `skip-ui-automation` スキル(Maestro + `skip app launch`)。
**見映えのするデモデータの投入と削除**が要る —— 実データのままでは撮れない。
撮る画面の候補: ホーム(カウントダウン + 重点 3 枚 + 積み上げ)/ 家トレ /
課題一覧の 3 層 / しばらく触れていない課題の 3 択 / 積み上げの節目 / 大会のねらい。

### 2.2 プライバシーポリシーの公開

本文は `docs/privacy.md` にある。GitHub Pages で公開し、
`Darwin/fastlane/metadata/{ja,en-US}/privacy_url.txt` の仮 URL
(`https://tantantatange.github.io/bad-note/privacy.html`)を実際の URL に合わせる。

### 2.3 申請そのもの

- Apple / Google のストア登録 → `Skip.env` の `APPLE_APP_STORE_ID` /
  `GOOGLE_PLAY_STORE_ID` を埋める
- Android の署名(`Android/app/keystore.jks` + `keystore.properties`。どちらも .gitignore 済み)
- 年齢レーティングとデータセーフティの申告(**収集なし・共有なし**で通る)
- 出荷前の順序: `swift test` → `skip verify` → `skip meta index` → `skip export -c release`

---

## 3. やらないと決めたこと

- **めざす姿の画像**(§7.1「+任意で画像 1 枚」)— 2026-08-22 に見送り。
  `PhotosPicker` が SkipUI 非対応で、iOS と Android の両方に自前実装が要る割に、
  テキストがあれば成立する
- **長押しドラッグ以外の並び替え手段の追加** — スワイプ / ドラッグ / 組み替えモードの
  3 つで足りている
- **初回だけのスワイプ / ドラッグのヒント** — 忘れた頃に効かず、消すための状態管理が要る。
  常設の控えめなフッター注記にした。**グリップ ⋮⋮ も不採用**(実際のドラッグは行の
  どこでも長押しなので、開始点だと誤解させる)
- **未整理の課題を層に混ぜる**(`statuses` に inbox を足す)— 整理前の課題が「いつか」に
  紛れて整理フローの意味が薄れる。課題一覧の末尾に独立したセクションで出す
- **チェック済みの行に消し込み線** — 「作業を消す」感が強い。名前を沈める表現にした
- **節目に称号を付ける** — 数字だけにした(このアプリの静かなトーンに合わせる)
- **目標大会を複数にする** — §5.1 の 8 週間切り替えと §4.4 の調整期が
  「種目ごとに 1 つ」を前提にしている。代わりに全大会が「ねらい」を持てるようにした

---

## 4. Phase 2(§9)

- 家トレのリマインド通知(§8 の「1 日 1 通」の制約との整理が必要なので Phase 2 送り)

- 定着確認の間隔ロジック(練習回数ベースで 3 回パス → 定着)
- 投資期間フラグ
- 大会 1 週間前に、その大会で過去に出た課題を表示
- 対戦相手ごとの記録
- ホーム画面ウィジェット
- ペア対応(`pair_id` を nullable で追加)
- 深掘り枠(今月の 1 つ + 言い換えログ)
- 崩れの記録

---

## 開発メモ

### Android 側のテストには JDK 21 が要る

Robolectric(Android SDK 36)は Java 21 を要求するが、シェルの `JAVA_HOME` は 17 を指している。
付け忘れると全テストが `Failed to create a Robolectric sandbox` で落ちる(テスト本体は 1 つも走らない)。

```
JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home swift test
```

Swift 側だけなら不要(`swift test --filter <TestClass>` で Gradle をスキップできる)。

### 両プラットフォームのビルド確認

`xcodebuild` の "Run skip gradle" フェーズが Android の APK まで作るので、1 コマンドで両方確認できる。

```
JAVA_HOME=... xcodebuild -workspace Project.xcworkspace -scheme "BadNote App" \
  -destination "generic/platform=iOS Simulator" -configuration Debug build
```

### Android エミュレータの起動

**SDK が 2 つある。** arm64 のシステムイメージは homebrew 側(`ANDROID_HOME` が指す場所)にあり、
`~/Library/Android/sdk/emulator` の方で起動すると
`detected a hanging thread 'QEMU2 CPU0 thread'` で固まって起動しない。**必ず homebrew 側を使う。**

```
/opt/homebrew/share/android-commandlinetools/emulator/emulator -avd emulator-34-medium_phone
```

`adb` は `~/Library/Android/sdk/platform-tools/adb`(どちらでも可)。

```
export PATH="$HOME/Library/Android/sdk/platform-tools:$PATH"
adb devices                                   # emulator-5554 が device になるまで待つ
adb -s emulator-5554 install -r -g .build/Android/app/outputs/apk/debug/app-debug.apk
adb -s emulator-5554 shell am start -n com.tange.badnote/bad.note.MainActivity
```

**Activity 名は `bad.note.MainActivity`**(Kotlin パッケージ名)。`.MainActivity` では起動しない。

### adb で合成できない操作がある

**長押しドラッグは `adb` で再現できない。** `input swipe` / `input draganddrop` /
`input motionevent` のいずれでも並べ替えが発火しなかったが、**指で操作すると動く**
(2026-08-21 に確認)。ドラッグまわりを変更したときは手で触って確かめること。

タップ・スワイプ・テキスト入力は `adb` で再現できる。

### 実機の DB を覗く

```
adb -s emulator-5554 shell "run-as com.tange.badnote sqlite3 files/badnote.sqlite 'PRAGMA user_version;'"
adb -s emulator-5554 shell "run-as com.tange.badnote sqlite3 files/badnote.sqlite 'SELECT key, value FROM app_meta;'"
```

`user_version` が `migrations` の本数と一致していればスキーマは最新。

### 通知が登録されたか確認する

SkipUI は Android では WorkManager 経由で予約する。`dumpsys alarm` ではなく JobScheduler を見る。

```
adb -s emulator-5554 shell "dumpsys jobscheduler | grep -c badnote"
```

### 画面の確認

```
adb -s emulator-5554 exec-out screencap -p > screen.png
adb -s emulator-5554 shell input tap <x> <y>
adb -s emulator-5554 logcat -d | grep -iE "FATAL|SQLite"
```

**既定タブは Welcome(テンプレート)なので、ホームに移動するまで DB は開かれない。**

iOS シミュレータは **画面を叩けない**(`simctl` にタップが無く、`osascript` は
補助アクセスが無いので System Events も使えない)。深い画面の見た目を確かめたいときは、
`ContentView.body` の先頭に一時的に

```swift
if true { return AnyView(PracticeLogView()) }
return AnyView(TabView(selection: $tab) { ... })
```

を入れてビルドし、`xcrun simctl io <UDID> screenshot` を撮ってから元に戻す。
**戻したあと `git diff` が空になることを必ず確認する。**

### 文字列を足したらカタログを同期する(2026-08-24)

UI 文字列(`Text("…", bundle: .module)`)を追加・変更したら、次を実行して
`Localizable.xcstrings` を同期する(CLI の xcodebuild は SwiftPM モジュールの文字列を抽出しない)。

```
python3 Scripts/sync-localizable.py
```

コードに無いキーは削除される。`displayName` 系の素の String は対象外(英語対応時に要対応)。

### 色は asset catalog 経由で両プラットフォームに効く(2026-08-22)

`Color("名前", bundle: .module)` は Android でも動く —— SkipUI が `Module.xcassets` の
colorset を読み、light / dark の appearances も解釈する。さらに **`AccentColor` という名前の
colorset が `Bundle.main` にあると、SkipUI が Material 3 の `primary` に自動適用する**。
Android の `Bundle.main` は「メインモジュールの `Resources/`」を指すので、
アプリのアクセントを変えるときは `Module.xcassets` 側の `AccentColor` を直すこと
(`Darwin/Assets.xcassets` は iOS にしか効かない。2 か所の値を揃える)。

### Skip の落とし穴(実際に踏んだもの)

- **`sorted()` / `map` / `filter` の戻り値は変更不可** — `insert` / `append` すると Android だけ
  実行時に `UnsupportedOperationException`。新しい配列に写してから触る
- **`Int64` と `Int` リテラルの `==` / `!=` は Kotlin で通らない** — 比較演算子(`<` `>`)は通るので
  Swift 側では気づけない。`Int64(0)` のように型を揃える
- **`XCTUnwrap` の戻り値から型を辿れない** — `var x: Issue = try XCTUnwrap(...)` と明示する
- **`XCTAssertThrowsError` は Kotlin に変換されない** — `Unresolved reference` になる。
  do / catch + フラグ + `XCTAssertTrue` で書く(2026-08-24)。
  **`db.transaction { () -> T in ... }` の型注釈付きクロージャも不可** ——
  skipstone が第 1 引数(mode)に割り当ててしまう。素の trailing closure で書く
- **`.sensoryFeedback` は Android で `VIBRATE` パーミッションが要る** — 無くてもビルドは通り、
  **振動する瞬間に `SecurityException` でクラッシュする**(Robolectric のテストでも出ない)。
  `Android/app/src/main/AndroidManifest.xml` に
  `<uses-permission android:name="android.permission.VIBRATE" />` を足す(2026-08-24 に踏んだ)
- **`Stepper(value:label:)` は Kotlin でオーバーロード解決できない** — Int 版と Double 版が
  ジェネリクス消去で衝突し `None of the following candidates is applicable` になる。
  `Stepper(タイトル文字列, onIncrement:onDecrement:)` の形にする(タイトルは
  `String` 型の変数で渡す —— リテラルだと LocalizedStringKey 版に取られる)(2026-08-24)
- **`Date.formatted(date:time:)` は端末のロケールで出る** — 日本語のみのアプリでも、
  英語の端末では「Aug 15, 2026」になる。画面に出す日付は `View/DateText.swift` を通す
  (2026-08-25。OS が描く日付ピッカーは対象外で、各 OS の作法に委ねる)
- **エミュレータの検証で `adb uninstall` を使わない** — アプリのデータごと消える。
  再インストールは必ず `adb install -r`。アイコンなど新規インストールの確認が要るときは、
  先に `run-as com.tange.badnote cp files/badnote.sqlite /sdcard/` などで**外に**退避する
  (アプリ内に置いたバックアップも一緒に消える)。2026-08-25 に実際に消した
- **`pm revoke` した権限は「ユーザーが拒否済み」扱いになり、許可ダイアログが二度と出ない** —
  Android 13+ の通知許可を試すときは、`-g` を付けない素のインストールで確かめる
  (`adb install` に `-g` を付けると全権限が自動付与されてダイアログが出ない)
- **fastlane メタデータの長さ制限は「バイト数」** — 文字数ではない。日本語は 1 文字 3 バイトなので
  30 バイトの `title.txt` は**実質 10 文字**、Play の `short_description`(80)は 26 文字。
  検証は `wc -c`(`wc -m` ではない)。**`skip verify` は `en-US` を必須のベースラインとして
  要求する**ので、日本語だけのアプリでも英語のリスティングが要る(2026-08-25)
- **`ShareLink` は Android ではテキスト共有(`EXTRA_TEXT`)のみ** — `item: URL` は
  ファイルではなく **URL の文字列**が送られる(SkipUI の ShareLink.swift を読んで確認。
  2026-08-24)。ファイル共有は不可。バックアップ(7.3)は JSON 文字列をそのまま共有する
- **SkipSQL の `transaction` はネストできない** — BEGIN を二重発行して
  `cannot start a transaction within a transaction` になる。複数リポジトリの書き込みを
  1 つに畳むときは、内側を `createInCurrentTransaction` のようなトランザクションを
  開かない版にして、いちばん外だけで `db.transaction` する(6.3)
- **`XCTAssertEqual(x, [])` の空配列リテラルは Kotlin で型推論できない** —
  `Cannot infer type for type parameter 'Element'` で全 JUnit テストが止まる。
  `[Int]()` のように型を書く(2026-08-23、MilestoneTests で踏んだ。
  **Swift 側のビルドと `swift test --filter` では気づけない** —— フルの `swift test` で初めて出る)
- **`.keyboardType` は macOS で使えない** — `Package.swift` が macOS を宣言しているので
  `#if` で囲む必要がある。ただし **`#if !os(macOS)` と書くと Skip が Android 側でも中身を落とす。**
  ビルドは通り、Android で数字キーボードの代わりにフルキーボードが出て初めて気づく。
  `#if os(iOS) || os(Android)` と対象 OS を並べて書く(2026-08-22)。
  `.navigationBarTitleDisplayMode` も同じ囲み方が要る
- **層のすべての行を `moveDisabled` にすると、その層に落とせなくなる** —
  空の層が見出し 1 行だけだと、長押しドラッグの落下先が存在しない。
  `TierLayout` は空の層を正しく扱えていたので**逆算ロジックではなく UI 側の問題**だった。
  落とし先になる行(`TierRowKind.placeholder`)を 1 つ置いて解決(2026-08-22)
- **アイコンは `.symbolset`** — `Image(systemName:)` は Android で描画されない
  (ただし `heart.fill` / `house.fill` / `gearshape.fill` など約 50 個は SkipUI が
  Material Icons に対応付けるため表示される。対応表は SkipUI の実装なので依存しない方が安全)
- **`setFoo(...)` という名前のメソッドは `var foo` と衝突する** — Kotlin では `var foo` が
  `setFoo()` を生成するため、同名のメソッドを書くと
  `Platform declaration clash: ... same JVM signature` になる。
  Swift 側では通るので Android のコンパイルまで気づけない。
  `selectFoo(...)` / `updateFoo(...)` のように改名する。
  **`var isEnabled` の setter は `setEnabled()`** になるので、`setEnabled(_:)` も衝突する
- **`.frame(maxWidth: .infinity)` はボタンの枠を広げない** — 広がるのは置き場所だけで、
  ボタン自体は中央に寄る。均等幅のチップにするには**ラベル側にも**同じ指定が要る。
  `SelectableChip`(`View/ChipStyle.swift`)にまとめてある(2026-08-22)
- **`PhotosPicker` は使えない** — `UIViewRepresentable` / `TimelineView` / `matchedGeometryEffect` も同様。
  `building-skip-ui` スキルの `references/components.md` の "Not Available in SkipUI" を先に見る
- **ジェネリック制約付き extension に init を足せない / コンストラクタに型独自のジェネリックを
  増やせない**(2026-08-23) — `struct Foo<A: View>` に対して `extension Foo where A == EmptyView { init(...) }`
  も、非ジェネリック型の `init<A: View>(...)` も、どちらも Android のコンパイルで落ちる
  (`This extension cannot be merged…` / `Kotlin constructors cannot introduce additional generics`)。
  ジェネリックは型宣言に置き、省略時は呼び出し側で `{ EmptyView() }` を渡す(`EmptyStateView` で採用)
