# タスク

`spec.md` のうち、何ができていて何が残っているか。

最終更新: 2026-08-23

**Phase 1 の機能は揃っている**(§7 の全 5 画面 / §4 の週次評価 / §8 の通知)。
**デザインの土台(色・文字・面と余白)も済み**、両 OS × ライト / ダークで実機確認した(2026-08-22)。
決めごとは「現状」の**デザインの決めごと**にまとめてある。

残りは **新機能(1)→ 画面の作り直し(2)→ 迷わせない工夫(3)→ 動きと手触り(4)→
品質(5)→ 配信(6)** の順。
**見出しに「—— 済」が付くものは完了。** 完了したものの内訳は末尾の
**「完了したこと」** に簡潔にまとめた。付いていない項目が残りのタスク。
**いま着手中は §2 画面の作り直し** —— 次は 2.6 設定(§2 の最後)。

---

## 現状

テスト 462 本。iOS / Android(Robolectric)の両方でパス。両プラットフォームでビルド成功。
(2026-08-23 に Android 側も実行し全パス —— 1.2 の空配列リテラルの Kotlin コンパイルエラーを
1 件直した。開発メモ「Skip の落とし穴」参照)

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
通知設定(§8)/ 家トレ・メニュー管理(§10)/ 積み上げ(1.2、ホームから開く)。

**まだ無いもの** — なし(Phase 1 + 新機能はすべて実装済み)。

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
Android エミュレータ(API 34 / SQLite 3.39.2)で DB 作成・マイグレーション 8 本の適用・
週次評価の初回実行・課題の登録まで通ることを確認した。

---

## 1. 新しく足す機能 —— **済**

**「毎日開きたくなる」ための機能。** 1.1 家トレ / 1.2 積み上げ とも完了。
内訳は末尾「完了したこと」。

---

## 2. 画面を作り直す ★ここから

**順番は毎日触る順。** まず 2.1 ホーム。
積み上げの見せ方は 1.2 の `StatsView` で決まったので、ホームからはそれを呼ぶ。

### 2.1 ホームが空っぽに見える —— **済(2026-08-23)**

重点の空き枠(`N/3` + 空き枠カード)と、積み上げカードの通算大きく表示。
内訳は末尾「完了したこと」。**実機確認済み(2026-08-23)。**

### 2.2 課題詳細の部品が素のまま —— **済(2026-08-23)**

習熟度バー・記録の `StatItem` カード・属性の導線と位置。内訳は末尾「完了したこと」。
**実機確認済み(2026-08-23)。**

### 2.3 一覧の行が単調 —— **済(2026-08-23)**

`MasteryIndicator` / `Badge` の部品化、大会一覧・アーカイブの `List` 化、
組み替えモードの導線色。内訳は末尾「完了したこと」。**実機確認済み(2026-08-23)。**

### 2.4 空の状態がただのグレー文字 —— **済(2026-08-23)**

`EmptyStateView` を新設して主要画面の空の状態に適用。内訳は末尾「完了したこと」。

### 2.5 通知時刻の指定が −/+ ボタン —— **済(2026-08-23)**

`DatePicker(.hourAndMinute)` に置き換え、分まで保存するようにした。
内訳は末尾「完了したこと」。**実機確認はまだ。**

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

## 完了したこと

新しい順。基盤(Phase 1 とデザイン土台)の詳しい内訳は「現状」を見る。

- **2.5 通知時刻を DatePicker に**(2026-08-23)—— −/+ ボタン(18 時 → 7 時に 11 回)を
  `DatePicker(displayedComponents: .hourAndMinute)` の 1 発指定に。**分まで持つようにした**:
  `NotificationSettings` に `practiceMinute` / `eveningMinute`(既定 0)、`app_meta` に
  `practice_reminder_minute` / `notification_evening_minute`(キー無し = 0 分なので既存 DB は
  マイグレーション不要)、`NotificationPlan.at` が分を発火時刻に載せる
  (`NotificationService` は元々 `date` の分まで登録している)。まとめ表示は「18:05」形式。
  テスト +4(Plan の分 3 本 / AppMeta の往復 1 本)。**実機確認はまだ。**
- **2.3 一覧の行**(2026-08-23)—— ① **行の習熟度を色 + 形に**: `View/MasteryIndicator.swift`
  (ミニ 4 分割バー + 段階名)を新設し、課題一覧 / 組み替えモード / ホームの重点カードに適用
  (ホームの文字チップは廃止)。② **バッジを部品化**: `View/Badge.swift`。
  課題詳細「よく戻ってくる課題」と大会一覧の目標大会印に適用。**★ の文字は廃止**
  (「目標大会(シングルス)」のバッジに)。③ **大会一覧とアーカイブを `List` に**
  (区切り線の決めごとどおり。カード廃止)。④ **組み替えモードの「外す」「選ぶ」を
  リンク色 + `.footnote` に**(灰色のままでは押せると分からない)。
  **spec §7.1 / §7.5 に反映済み。実機確認済み(2026-08-23)。**
- **2.2 課題詳細の部品**(2026-08-23)—— ① **習熟度を横 4 分割のバーに**(`●○` の文字を廃止。
  埋まった数 = 現在のレベル、`Palette.accent` / `.surfaceRaised`、現在の段階名を添える。
  VoiceOver は label + value「2/4 ノックでできる」)。② **記録を `StatItem` カードに**:
  数字部品 `View/StatItem.swift` を新設(22pt semibold + 単位・ラベル `.caption`)し、
  積み上げ画面の 2 スタットと共通化(あちらの `spacing: 2` は 4 の倍数ルールに正規化)。
  ③ **「属性を見る」を bordered + `.footnote`** に(裸の青リンク廃止)、開いた中身は `Card` に。
  ④ **アクションを属性より上に**(「克服した」を折り返しの外に沈めない)。
  **spec §7.3 に反映済み**(2・4 の形、6・7 の入れ替え)。**実機確認済み(2026-08-23)。**
- **2.1 ホームが空っぽに見える**(2026-08-23)—— ① **重点の空き枠を見せる**:
  見出しに `N/3`(一覧側と同じ表記)、3 件未満のときは「空き枠 / 選ぶ」カードを
  枠の数だけ置き、押すと組み替えモードへ(0 件のときは 2.4 の `EmptyStateView` に譲る。
  件数の催促はしない §5.3)。② **通算をホームにも大きく出すと決めた**:
  積み上げカード(`home-stats-link`)を見出し + 34pt の通算(`heroTimeText`、分まで)+
  導線文言に作り替え。`HomeModel.lifetimeMinutes` を追加(`StatsRepository` 経由 §10.3)。
  通算 0 のときは大きな「0分」を出さず案内文だけ。**spec §7.1 に反映済み**(空き枠 / 積み上げ
  を項目 3・5 に追記)。**実機確認済み(2026-08-23)。**
- **2.4 空の状態の共通化**(2026-08-23)—— `EmptyStateView`(`View/EmptyStateView.swift`。
  アイコン + 一言 + 任意の「次の 1 手」ボタン)を新設し、ホーム / 練習ログ入力 / 課題詳細 /
  積み上げ / 大会一覧に適用。次の 1 手が無い所(記録待ち・めざす姿 §7.1)はボタンを省く。
  **未適用**: 課題一覧の空の層(ドラッグの落とし先。構造を変えない §7.4)/ 家トレ(既に導線あり)/
  インボックス・アーカイブ・組み替えの「片づいた」表示(追って要検討)。
- **1.2 積み上げの可視化**(2026-08-23)—— `StatsView` / `StatsModel` を新設し、
  ホームの「積み上げ」カード(`home-stats-link`)から開く。通算(主数字)/ 月ごとの自前縦棒
  (`Rectangle`、直近 6 か月)/ 種類の内訳の横棒。`StatsRepository` に `lifetimeMinutes()` /
  `monthlyMinutes()` / `minutesByCategory()` を追加(合計は必ずここ経由 §10.3)。
  §5.3 遵守(合計だけ。ストリーク / 目標 / 平均は出さない)。テスト +5(計 455)。
  **モチベ強化**(2026-08-23)—— 主役を作り直した。通算は**分まで**出して毎回桁が動くように
  (`heroTimeText`)、開くと 0 からカウントアップ(`.task` + `Task.sleep`。`.contentTransition`
  は SkipUI 非対応なので state を刻んで再描画)、トロフィー + 温かい一言 +
  **上達(通算レベルアップ)/ 克服(定着課題数)** を併記(`StatsRepository.lifetimeLevelUps()` /
  `settledIssueCount()`。CLAUDE.md「積み上げ側の数字」)。テスト +2(計 457)。
  **節目と月グラフ強調**(2026-08-23)—— ⑧ 到達済みの「節目」チップ(`Logic/Milestone.swift`。
  1/5/10/25/50/100/200/500/1000 時間。**到達済みだけを祝い、次までの残りは出さない**=§5.3準拠)、
  最新の節目だけ accent。**究極の目標=1 万時間(1 万時間の法則)** を行末に北極星として常設
  (枠線だけ。到達で塗りつぶし。残り時間は出さない)。④ 月グラフは**今月を強調**(accent + 「今月」ラベル + 値を上に。過去は薄い accent)、
  **0 分の月も薄いスリバー**で残す(空列=「途切れ」に見せない)。テスト +4(計 461)。
  **仕上げ**(2026-08-23)—— ⑤ 月ラベルに年を添える(左端・1 月に「'26」。`yearLabel` / `isJanuary`)/
  ⑥ 内訳バーは最小幅 6pt を保証 + カテゴリ別の accent 濃淡(`barWidth` / `categoryOpacity`)/
  ⑨ VoiceOver ラベルを全要素に付与(棒・内訳行・2 スタット・節目 / 1 万時間チップ)。
  **UI レビュー ①〜⑨ は実装完了、iPhone 実機で確認済み**(2026-08-23。Dynamic Type 含む)。
  **Android エミュでも確認済み**(2026-08-23。API 34)—— 主役の分表示・節目チップ(1/5 時間 + 1 万時間枠)・
  今月強調と年ラベル・0 分月のスリバー・内訳の濃淡と最小幅(筋トレ 45 分も可視)まで、
  クラッシュなく描画。sqlite3 でダミー練習を投入して検証。

  **`spec.md` §10.5「積み上げ画面」を追記済み**(2026-08-23)。
  節目セクションの表示条件は **通算 1 時間から**で確定(§7.1 の精神。0 時間に遠いゴールだけ見せない)。
  **積み上げ画面(1.2)は完了 —— 残タスクなし。**
- **1.1 家トレ**(2026-08-22)—— `training_menu` / `training_log`(マイグレ v10)と
  `TrainingRepository` / `StatsRepository` を新設。家トレ画面とメニュー管理。チェック時に
  分数を写して固定(§10.3)。タブを 4 つに。仕様は `spec.md` §10。テスト +22(計 450)。
  **やり残し**: iOS 実機確認。
- **基盤**(〜2026-08-22)—— Phase 1 の全 5 画面 / 週次評価(§4)/ 通知 3 種(§8)、
  デザインの土台(色・文字・面と余白)、タブ構成、アイコンの `.symbolset` 化、テンプレ削除。
  内訳と決めごとは「現状」。

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
