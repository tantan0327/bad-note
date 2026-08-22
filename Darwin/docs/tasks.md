# タスク

`spec.md` のうち、何ができていて何が残っているか。

最終更新: 2026-08-22

**Phase 1 の機能は揃っている**(§7 の全 5 画面 / §4 の週次評価 / §8 の通知)。
**デザインの土台(色・文字・面と余白)も済み**、両 OS × ライト / ダークで実機確認した(2026-08-22)。
決めごとは「現状」の**デザインの決めごと**にまとめてある。

残りは **新機能(1)→ 画面の作り直し(2)→ 迷わせない工夫(3)→ 動きと手触り(4)→
品質(5)→ 配信(6)** の順。
**1.1 家トレは実装済み**(2026-08-22)。次の一手は **1.2 積み上げ**(`StatsRepository` は新設済み)。

---

## 現状

テスト 450 本。iOS / Android(Robolectric)の両方でパス。両プラットフォームでビルド成功。

**データ層** — Repository は 7 つ(`Issue` / `Practice` / `Competition` / `Vision` / `Tag` /
`Training` / `Stats`)。加えて `AppMeta` / `StaleFlag` / `StaleEvaluator`。
**画面に出す累計は `StatsRepository.totalMinutes` だけから取る**(§10.3。
`PracticeRepository` 直では家トレの分が落ちる)。

**テーブル** — マイグレーション 10 本で §6 と §10.4 のテーブルはすべて作成済み。

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
通知設定(§8)/ 家トレ・メニュー管理(§10)。

**まだ無いもの** — 積み上げの可視化(1.2)。`spec.md` への節は着手時に §10 に書き足す。

**原文の欄のラベル**(2026-08-22、実使用より) — **画面ごとに変えている。**

- 練習ログ入力(§7.2): **「追加する課題」** —— これから何が起きるか(課題が増える)を伝える
- 課題詳細 / 登録・編集 / インボックス整理: **「もとの言葉」** ——
  その文が何なのか(編集しない原文)を伝える

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

詳細画面のタイトルは**その画面の固有名**(課題名・大会名)を inline で出す。
「課題」「大会」のような中身の無い大タイトルは出さない
(`.navigationBarTitleDisplayMode` は macOS 不可 → `#if os(iOS) || os(Android)` で囲む)。
一覧系の大タイトル(課題 / 大会 / 設定など)は中身を表す言葉なのでそのまま。
例外 —— 練習時間入力の分数(52pt)は入力部品の表示で表の外。

**面と余白**(新しい面はこの 3 種類から選ぶ):

| 部品 | 形 | どこで決まるか |
|---|---|---|
| カード | 面 `Palette.surface` / 内側 12 / 角丸 8 / 幅いっぱい | `View/Card.swift`(`Card { ... }`)。強調の帯は `Card(background: Palette.surfaceRaised)` |
| バッジ(表示のみ) | `.caption` / 横 8 縦 4 / 角丸 4 / `Palette.surfaceRaised` | まだ直書き 2 箇所。2.3 で部品化する |
| ピル(押せる絞り込み) | `.footnote` / 横 12 縦 8 / 角丸 16 | 課題一覧の絞り込み行のみ |

- **間隔は 4 の倍数だけ**(`4` / `8` / `12` / `16` / `20` / `24`)
- **余白は 2 段階** —— 画面の外周は `.padding()`(= 16)、カードの内側は `Card` が持つ 12
- **区切り線** —— 同じ形の行を選ぶだけの画面 = `List`(設定 / 課題一覧 / 組み替えモード)。
  役割の違うブロックが縦に並ぶ画面 = カード(ホーム / 課題詳細 / 大会詳細 / 練習ログ入力 /
  インボックス整理)。大会一覧とアーカイブは一覧なのにカード —— 2.3 で `List` に寄せる

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
Android エミュレータ(API 34 / SQLite 3.39.2)で DB 作成・マイグレーション 8 本の適用・
週次評価の初回実行・課題の登録まで通ることを確認した。

---

## 1. 新しく足す機能 ★ここから

**「毎日開きたくなる」ための機能。** 残りは 1.2 のみ。

### 1.1 家でのトレーニングを毎日こなす画面 —— **済(2026-08-22)**

仕様は **`spec.md` §10** に書き足した(概念 / 画面 / 合算のルール / テーブル)。実装:

- **データ層** — マイグレーション 10 本目で `training_menu` / `training_log`。
  `TrainingRepository`(メニュー CRUD・チェック)と
  **`StatsRepository`(積み上げ集計の唯一の入り口)** を新設。
  ホームと練習ログの保存後サマリを `StatsRepository` に付け替えた
  (3 箇所目の積み上げ画面は 1.2 で)
- **`training_date` はローカルの暦日 TEXT**(`2026-08-22`、`Data/DayStamp.swift`)。
  `practice_date`(UTC タイムスタンプ)と形式が違う。§10.4 に明記
- **チェック時に分数を写して固定**(§10.3)。後からメニューの目安を直しても
  過去の積み上げは変わらない —— テストで担保
- **タブ 4 つ** — ホーム / 家トレ / 課題 / 大会。`fitness_center` の `.symbolset` を追加
  (チェック行用に `check_circle` / `circle` も)
- **画面** — 家トレ(`List`、日付をさかのぼれる、チェックは色 + 形、
  チェックが付いた分だけの合計をフッターに)/ メニュー管理(追加・編集・
  長押しドラッグで並び替え・アーカイブ)。新画面は `accessibilityIdentifier` 付き(5.1 の先取り)
- 「まだ決めていないこと」の採否 —— チェックは外せる ✓ / さかのぼり ✓ /
  曜日ごとの既定メニューは見送り(§10.2 に記録)
- テスト 22 本追加(計 450)。Android エミュレータで **v9 → v10 の移行**
  (既存データあり)と、メニュー作成 → チェック → DB 書き込みの一連を確認済み。
  **iOS 実機での確認はまだ**

### 1.2 積み上げが見えない

いま積み上げを表しているのは **ホームの `buildUpText` の 1 行だけ** ——
`今月 3 時間 / レベルアップ 0`。それ以外にどこにも無い。

**データはもう全部ある。** `practice.practice_date` と `minutes`、種類は `practice.kind`、
家トレは `training_log`。合計は `StatsRepository`(1.1 で新設済み)から取る。
`PracticeRepository` 単体で足すと家トレが落ちる(§10.3)。**足りないのは見せ方だけ。**

やること:

1. **通算を大きく出す。** 今月ではなく**始めてからの合計**。この数字は減らないので、
   開くたびに必ず増えている。自信になるのはここ
2. **月ごとの棒グラフ**(直近 6〜12 か月)。1 本ずつ伸びるのが見える
3. **種類の内訳**(全体練習 / 個人練習 / ゲーム練習 / 筋トレ)。`practice.kind` にすでに入っている
4. 置き場所 —— ホームか、ホームから開く「積み上げ」画面。
   §5.1 の 8 週間での切り替えを壊さないこと

**§5.3「やらないこと」との線引き**(ここを外すと逆効果になる):

- **ストリーク(連続日数)は実装しない。** 日ごとのカレンダーやヒートマップは
  **空白の日が「途切れ」に見える**ので、名前が違うだけで同じ罠。
  **月・週の「合計」で見せる**(合計は減らない)
- **目標値やノルマを置かない。** 「今月あと N 時間」は §5.3 の裏返し
- **平均や「先月より少ない」といった解釈も出さない**
  (CLAUDE.md「アプリは解釈や警告を出さない」)

実装メモ —— **SkipUI に Swift Charts は入っていない**(`Sources/SkipUI` に Charts 関連なし)。
`Rectangle` / `Capsule` を積む自前の棒グラフになる。`GeometryReader` は SkipUI 対応済み。

---

## 2. 画面を作り直す

**順番は毎日触る順。** ホーム(2.1)は 1.2 の積み上げとセットでやる。

### 2.1 ホームが空っぽに見える

画面の**上から 1/3 しか使っていない。** 下 2/3 が完全な空白で、作りかけに見える。

- **重点の空き枠が見えない。** §7.1 は「カード 3 枚」「スクロールなしで 3 つ見える」と
  書いており、**空き枠が見えること自体が「あと 2 つ選べる」の合図**になる。
  一覧側は `1/3` と出るのにホームには無い
- 「練習を記録する」の下に何も無い。**今月の累計時間**(積み上げ側の数字は出してよい)や
  **次の大会までの日数**は、材料がすでに `HomeModel` にある。
  積み上げの見せ方そのものは **1.2** で決めるので、あわせてやる
- タブが 4 つに増えると(1.1)空きがさらに目立つ

### 2.2 課題詳細の部品が素のまま

- **習熟度が `●` `○` の文字。** 4 段階の進み具合を表す部品として作られていない。
  横 4 分割のバーか、点をつないだ線にする
- **記録(累計時間 / 重点にした / 再浮上)が裸の 3 カラム。**
  数字が主役の場所なのに、面も区切りも無い(数字の大きさもここで決める。今は `.title3`)
- 「属性を見る」が**裸の青リンク**。他の画面の導線と形が違う
- 「克服した(定着確認へ)」が画面のいちばん下、折り返しの外にいる

### 2.3 一覧の行が単調

課題一覧・大会一覧・アーカイブ・組み替えモードの行が、
**すべて「太字 1 行 + 灰色 1 行」の同じ形**で、目が滑る。

- 課題の行の**習熟度が文字だけ**。色か形で入れる
- 大会一覧の `★ 目標大会(シングルス)` が**文字の星**。バッジにする
- **バッジを部品にする**(直書きが 2 箇所 —— ホームの習熟度チップ /
  課題詳細の「よく戻ってくる課題」。形は「現状」の面と余白の表)
- **大会一覧とアーカイブを `List` に寄せる**(区切り線の決めごと参照。
  一覧なのにカードで作ってある)
- 組み替えモードの「外す」「選ぶ」が**灰色の文字で、押せると分からない**

### 2.4 空の状態がただのグレー文字

「まだ書かれていません」「重点はまだ決まっていません」「まだ記録がありません」
「今週の重点はまだありません」—— **全部ただの灰色 1 行。**
アイコン + 一言 + 次の 1 手のボタン、の形に揃える。3.1 と同じ話。

### 2.5 通知時刻の指定が −/+ ボタン

1 時間ずつ押す作りで、18 時 → 7 時に変えるのに 11 回押す。
`DatePicker(displayedComponents: .hourAndMinute)` が素直
(SkipUI 対応済み。§8 は時刻の指定方法まで決めていない)。

### 2.6 設定が 3 行しかない

「定着した課題」「通知」「バージョン」だけで 1 画面使っている。
**§4.2 の stale の閾値はまだ画面に出ていない**(`AppMetaRepository` にはあるが編集手段が無い)。
行にアイコンを付け、閾値の設定を足す。

---

## 3. 迷わせない工夫

### 3.1 初回起動で何をすればいいか分からない

§7.1 は「初回は促さない」としているが、それは**めざす姿の話**。
最初の 1 歩(練習を記録する、または課題を 1 つ足す)への誘導は別に置ける。

### 3.2 未整理の課題がどこにも出ない

課題一覧は `status = active` のみ。**練習ログで書いた 1 行は inbox なので一覧に出ない。**
「追加する課題」に書いたのに課題タブで見つからない、という体験になる。

- 一覧に「未整理 N 件」のセクションを足す(§5.3 のバッジ禁止に触れない形で)
- または `IssueListModel.statuses` を `[.inbox, .active]` にする

### 3.3 スワイプとドラッグに気づけない

層の移動は 3 通りあるが、**画面上に手がかりがあるのは「組み替える」だけ**。
スワイプは隠れており、ドラッグは長押しが要る。初回だけヒントを出すか、
行に小さな `⋮⋮` のグリップを見せるか。

---

## 4. 動きと手触り

**無くても使えるが、有ると作り込まれて見える部分。** 1〜2 が終わってから。

### 4.1 状態が変わっても何も動かない

チップの選択・層の移動・保存・レベルアップが**すべて瞬間に切り替わる。**
`withAnimation` を当てる場所を決める(選択は速く、層の移動はゆっくり)。

### 4.2 触覚フィードバックが無い

手応えの選択・層の移動・保存は、画面を見ずに操作することがある。
SkipUI に `UIImpactFeedbackGenerator` 相当があるか要確認。

### 4.3 iOS と Android で細部が別物

色は揃った(済)。残っている差:

| | iOS | Android |
|---|---|---|
| ツールバー | 丸いピル(iOS 26) | 文字だけ |
| 日付ピッカー | 灰色のピル `2026/08/22` | 青文字 `Aug 22, 2026` |

「揃えるのか、各プラットフォームの作法に委ねるのか」を決める。
Skip の既定は後者で、それ自体は悪くない。**決めていないことが問題。**

---

## 5. 品質の土台

### 5.1 アクセシビリティが手つかず

- **`accessibilityIdentifier` が 0 件。** Maestro の UI テストが書けない
  (`skip-ui-automation` スキルは「すべての操作可能な View に付ける」としている)
- `accessibilityLabel` は設定の歯車のみ。アイコンだけのボタンに要る
- Dynamic Type(文字を大きくしたとき)未確認。大きい数字や 1 行チップが崩れやすい

### 5.2 ローカライズの抽出が動いていない

`Localizable.xcstrings` が実際の文字列に追いついていない(2026-08-22 時点で 99 キー)。
`SWIFT_EMIT_LOC_STRINGS = YES` はアプリターゲットに付いているが、文字列は SwiftPM 側の
`BadNote` モジュールにあるため、コマンドラインの `xcodebuild` では新しいキーが抽出されない。
カタログに無いキーはキー自体(=日本語)が出るので**動作に支障は無い**。
日本語のみで出すなら実害は無いが、英語対応の前に直す必要がある。

### 5.3 DB 接続がモデルごと

**実際に `database is locked` を踏んだ**(2026-08-22、通知設定の保存時)。
設定を書いている最中に別の接続を開いたのが原因。通知まわりは
「DB を使う部分(同期)」と「OS に登録する部分(非同期・DB を触らない)」に分けて回避したが、
**接続を共有していないという根本は残っている**。
インメモリ DB のテストでは接続が 1 本なので再現しない。実機でしか出ない。

**練習ログとコーチの言葉が別トランザクション**(Repository が別)も同じ章の宿題。

---

## 6. 配信の準備

**スクリーンショットは作り直した画面(2)で撮る。** アイコン(6.1)はいつでも作れる。

### 6.1 アプリアイコン

**テンプレートのまま。** `Darwin/Assets.xcassets/AppIcon.appiconset/` は `Contents.json` だけで、
Android の `mipmap-*` も無い。**アイコンが無いと申請できない。**
ブランド色は決まっている(`#5C6BC0`)のでいつでも作れる。

```
skip icon --background "#5C6BC0" symbol.svg
```

### 6.2 ストアのメタデータとスクリーンショット

`Skip.env` は `PRODUCT_NAME = BadNote` / `com.tange.badnote` のまま。決めるもの:

- 表示名(日本語のストア名)、サブタイトル、説明文、キーワード、カテゴリ、年齢レーティング
- **スクリーンショット** — 端末サイズごとに必要。`skip-ui-automation` スキルの
  Maestro + `skip app launch` で撮る手順がある
- **プライバシー情報** — このアプリは**通信もデータ収集もしない**ので「収集なし」で通る。
  ただしプライバシーポリシーの URL は要求される
- 置き場は `Darwin/fastlane/metadata/` と `Android/fastlane/metadata/android/`
  (`skip-localization` スキルにディレクトリ構成とバイト数の上限がある)

### 6.3 データの書き出し

**今このアプリはデータが消えたら終わる。** 数か月分の練習ログと課題が
端末の `badnote.sqlite` にしか無い。iCloud バックアップの対象ではあるが、
**ユーザーが自分で吸い出す手段が無い。**

配信するなら、せめて 1 つは用意したい。

1. 書き出し(JSON か CSV を共有シートで出す)—— 最小。`ShareLink` は SkipUI 対応済み
2. 読み込み(機種変更時の復元)
3. iCloud / Google Drive 同期 —— Phase 2 以降

---

## やらないと決めたこと

- **めざす姿の画像**(§7.1「+任意で画像 1 枚」)— 2026-08-22 に見送り。
  `PhotosPicker` が SkipUI 非対応で、iOS と Android の両方に自前実装が要る割に、
  テキストがあれば成立する
- **長押しドラッグ以外の並び替え手段の追加** — スワイプ / ドラッグ / 組み替えモードの
  3 つで足りている

---

## 7. Phase 2(§9)

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
