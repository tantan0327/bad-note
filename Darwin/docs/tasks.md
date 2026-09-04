# タスク

`spec.md` のうち、何ができていて何が残っているか。

最終更新: 2026-09-05

**アプリとして作るものは終わっている。** Phase 1 の機能・デザインの土台・磨き込み・
UI/UX の改善はすべて完了し、実機で確認済み。テストで守れない長押しドラッグも
手で確かめてある(2026-08-31)。決めごとは「現状」の**デザインの決めごと**と
`spec.md` に集約してある(完了したタスクの一覧はここでは持たない。履歴は git log)。

**残っているのは §1 の配信** —— スクリーンショットの撮影、
プライバシーポリシーの公開、ストア登録。

2026-08-31 に**残り練習回数を推定から実数に変えた**(§5.2)。
「あと N回」が実際と合わないという報告を受け、練習予定日(§7.6)を登録して
数える方式にした。`PracticeForecast` は役目を終えたので削除。

2026-09-04 に**予定日の登録を月カレンダーに変えた**(§7.6)。
1 日ずつ `DatePicker` で入れるのが面倒という報告。日をタップして入れる / 外す形にし、
`DatePicker` は「別の月へ」に役割を変えて残した。

2026-09-05 に**手応えの 3 つに違う意味を持たせた**(§3.2)。
評価しても何が変わるのか分からないという報告 —— 調べると `closer` と `next` は
コード上まったく同じ扱いで、唯一の仕組み(できた 3 回で昇格提案)も発火するまで見えなかった。
**近づいた を中立にし、次にやる が続いたら戻す提案を出し、現在地を記録直後と課題詳細に出す**。
あわせて既存バグ 2 件(昇格直後の再提案 / 手応え未選択でも提案が湧く)を直した。

---

## 現状

テスト 689 本(JUnit 690)。iOS / Android(Robolectric)の両方でパス。
両プラットフォームでビルド成功。`skip verify`(ストアのメタデータ)も通る。

**データ層** — Repository は 9 つ(`Issue` / `Practice` / `PracticePlan` / `Competition` /
`Vision` / `Tag` / `Training` / `Stats` / `Export`)。加えて `AppMeta` / `StaleFlag` / `StaleEvaluator`。
**画面に出す累計は `StatsRepository.totalMinutes` だけから取る**(§10.3。
`PracticeRepository` 直では家トレの分が落ちる)。

**テーブル** — マイグレーション 13 本で §6 / §10.4 / §7.5(大会のねらい)のテーブルと列は
すべて作成済み。**足すときは `migrations` の末尾に 1 要素。既存の要素は書き換えない。**

**ロジック**(すべて純粋関数・テスト済み)

| 型 | 仕様 |
|---|---|
| `PracticePlan` | §5.2 残り練習回数(登録された練習予定日を数える。推定しない) |
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
| `MonthGrid` | §7.6 月カレンダーの升目(常に 42 個、先頭は日曜) |
| `MasteryTrend` | §3.2 手応えの向き(できた=進む / 近づいた=中立 / 次にやる=仕切り直し) |
| `MasteryStanding` | §3.2 現在地と提案の**唯一の入り口**(上げる / 戻す / 克服) |

**画面** — ホーム(§7.1)/ 練習ログ入力(§7.2)/ 課題一覧(§7.4 の一部)/ 課題の登録・編集(§3)/
インボックス整理 / めざす姿の編集(§7.1、テキストのみ)/ 大会一覧・登録(§7.5 の一部)/
課題詳細(§7.3)/ 週次の組み替えモード(§7.4)/ アーカイブ(§7.4)/ 大会詳細・振り返り(§7.5)/
通知設定(§8)/ 家トレ・メニュー管理(§10)/ 積み上げ(ホームから開く)/
データの書き出し(§11、設定から)/ 練習予定日(§7.6、設定から。まとめて追加も)。

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

**日付の出し方** —— **画面に出す日付は必ず `View/DateText.swift` を通す。**
`formatted(date:time:)` は**端末のロケール依存**で、日本語以外の端末だと
「Aug 15, 2026」と英語が混ざる(使用箇所はゼロに保つ)。用意してあるのは 2 つだけ:

| 関数 | 形 | 使う場面 |
|---|---|---|
| `DateText.day(_:asOf:)` | 「8月24日」 | 一覧やメタ情報(課題の作成日、アーカイブした日) |
| `DateText.dayWithWeekday(_:asOf:)` | 「8月24日(月)」 | **その日そのものが主役**(家トレの見出し、大会の開催日) |

- **年は今年と違うときだけ出す**(「2027年2月20日(土)」)。常に出すと冗長で、
  出さないと去年の記録が今年のものに見える。目標大会は半年先=翌年になることが多い
- **例外 1: `DateText.month(_:)`(「2026年9月」)は年を常に出す** ——
  カレンダーは何か月も先へ送れるので、年が無いと現在地が分からない
- **例外 2: カレンダーのセルの数字は `Text(verbatim:)`** —— 書式を持たないので
  `DateText` を通さない。ただし `accessibilityLabel` は `DateText.dayWithWeekday` を通す
- **OS が描く日付ピッカーは対象外**(上のプラットフォーム差の線引きに従う)

**面と余白**(新しい面はこの 3 種類から選ぶ):

| 部品 | 形 | どこで決まるか |
|---|---|---|
| カード | 面 `Palette.surface` / 内側 12 / 角丸 8 / 幅いっぱい | `View/Card.swift`(`Card { ... }`)。強調の帯は `Card(background: Palette.surfaceRaised)` |
| バッジ(表示のみ) | `.caption` / 横 8 縦 4 / 角丸 4 / `Palette.surfaceRaised` | `View/Badge.swift`。押せる部品には使わない |
| ピル(押せる絞り込み) | `.footnote` / 横 12 縦 8 / 角丸 16 | 課題一覧の絞り込み行のみ |
| 行の習熟度 | ミニ 4 分割バー + `.caption` の段階名 | `View/MasteryIndicator.swift`。課題詳細のバーの縮小版 |
| カレンダーのセル | `.footnote` / 高さ 40 / 角丸 8 / 幅は 7 等分 / 登録済みは `Palette.accent` 塗り | `View/PracticePlanView.swift`。列の間隔 2 は 4 の倍数の例外(幅が足りない) |

- **動き** —— 選択・チェック・バーの伸縮 = `Motion.select`(easeOut 0.15)、
  行の移動・出入り・画面の切り替わり = `Motion.move`(easeInOut 0.3)。
  `View/Motion.swift` から取り、duration を直書きしない
- **`accessibilityIdentifier` の命名** —— kebab-case で「画面-部品(-id)」
  (`home-record` / `issue-row-3` / `practice-kind-whole`)。操作可能な View には必ず付ける
- **プラットフォーム差の線引き**(2026-08-24 決定)——
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

**通知**(§8)は 3 種類とも実装済み(練習前 / 大会当日の夜 / 週 1 回)。
**練習前の通知は曜日ではなく登録された練習予定日に出す**(2026-08-31。予定日を
入れていなければ鳴らない)。**1 日 1 通まで**で、
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

## 1. 配信に残っている作業

### 1.1 ストアのスクリーンショット

fastlane のテキストと設定は済み(`skip verify` が通る)。**画像だけが無い。**

- `Darwin/fastlane/screenshots/ja/N_ja.png` —— iPhone 6.7"(1290×2796)
- `Android/fastlane/metadata/android/ja-JP/images/phoneScreenshots/N_ja-JP.png`
- Play は加えて `images/icon.png`(512×512)と `featureGraphic.png`(1024×500)
- 各ストア 1 ロケールにつき最低 1 枚、最大 10 枚

手順は `skip-ui-automation` スキル(Maestro + `skip app launch`)。
**見映えのするデモデータの投入と削除**が要る —— 実データのままでは撮れない。
撮る画面の候補: ホーム(カウントダウン + 重点 3 枚 + 積み上げ)/ 家トレ /
課題一覧の 3 層 / しばらく触れていない課題の 3 択 / 積み上げの節目 / 大会のねらい。

### 1.2 プライバシーポリシーの公開

本文は `docs/privacy.md` にある。GitHub Pages で公開し、
`Darwin/fastlane/metadata/{ja,en-US}/privacy_url.txt` の仮 URL
(`https://tantantatange.github.io/bad-note/privacy.html`)を実際の URL に合わせる。

### 1.3 申請そのもの

- Apple / Google のストア登録 → `Skip.env` の `APPLE_APP_STORE_ID` /
  `GOOGLE_PLAY_STORE_ID` を埋める
- Android の署名(`Android/app/keystore.jks` + `keystore.properties`。どちらも .gitignore 済み)
- 年齢レーティングとデータセーフティの申告(**収集なし・共有なし**で通る)
- 出荷前の順序: `swift test` → `skip verify` → `skip meta index` → `skip export -c release`

---

## 2. やらないと決めたこと

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
- **組み替えの候補行に stale / 最後に触れた日を出す** — §4.3 の週 1 回の提示が
  担当している。3 件を選ぶだけの画面に毎行の経過を出すと騒がしくなる
  (判断材料は影響度の目印だけで足りる)

---

## 3. Phase 2(§9)

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

### 保存形式は「保存された文字列そのもの」を検査する(2026-08-31)

リポジトリ経由の往復テストは、**書いて読むのが同じフォーマッタ**なので
**書式が変わっても通ってしまう**(往復は成立するが、既存データが読めなくなる)。

- `SQLTimestamp` は `testEventDateIsStoredAsUTCISO8601Text` /
  `testPracticeDateIsStoredAsUTCISO8601Text` が保存文字列を直接検査していて守られている
- `DayStamp`(家トレの `training_date`)は無防備だったので同じ守り方を足した
  (`DayStampTests` + `testTrainingDateIsStoredAsLocalDayText`)

**期待値はリテラルで書く。** `DayStamp().text(from:)` と突き合わせると同じ穴に落ちる。
**日付はゼロ埋めが要るもの**(1 月 4 日など)を選ぶ —— 11 月 14 日のような 2 桁同士だと
`yyyy-M-d` に変わっても 10 文字のままで気づけない(実際にこの見落としを踏んだ)。

**書いたテストは一度わざと壊して検出力を確かめる。** 上の見落としはそれで見つけた。

### 仕様の言葉に対応する入力が実装に無いときは、どちらかが嘘(2026-08-31)

`spec.md` §5.2 は「**直近の**平均練習頻度から推定する」と書いていたのに、
`PracticeForecast.averageIntervalDays` に**「直近」を決める引数が無かった**。
実際は全履歴の最古と最新の 2 点を結んだ平均で、使い始めの頻度が一生効き続けていた。
テスト 16 件は等間隔の日付しか使っておらず、**ペースが変わる場合を 1 件も見ていなかった**
ので全部通っていた。

**仕様の形容詞(直近の / 最近の / 主要な)に対応する引数やクエリが無ければ、
実装が仕様に追いついていないか、仕様が実態を書いていない。** どちらかを直す。

このケースは推定をやめて**登録された練習予定日を数える実数**に置き換えた(§5.2 / §7.6)。
推定の精度を上げるより、本人が決めた事実を数える方が説明がつく。

### スキーマの更新経路(2026-08-31)

他のテストはすべて**空のインメモリ DB から始まる**ので、「0 から全部を一気に適用する」
経路しか通っていなかった。実際の端末にあるのは**途中のバージョンでデータ入りの DB**。
`MigrationTests`(12 件)を新設。テストが前半だけを適用できるよう
`AppDatabase.migrations` を計算プロパティとして外に出した
(`static let` のクロージャ配列は並行性の検査に引っかかる)。

**「既存の要素を書き換えない」を守るテストの書き方に注意。**
最初、新規インストールと更新後のスキーマを突き合わせる形で書いたが、
**「古い DB」を同じ `migrations` から作り直していたので何も検出できなかった** ——
既存の 1 本目に列を足す変異が素通りした。上の「保存された文字列そのものを検査する」と
同じ盲点で、**両側が同じ出どころだと比較が成立しない**。

いまは `MigrationTests.pinnedSchema` に**テーブルごとの列名を直接書いて**固定してある。
**この一覧を直してよいのは、マイグレーションを末尾に足したときだけ。**
比較はテーブルごとに回す(丸ごと 1 回で比べると 16 行が 1 つの文字列になって読めない)。

`SQLContext.migrate` は `userVersion..<migrations.count` で回るので、
**新しい DB に短い配列を渡すと範囲が逆転する**。必ず新規の DB に前半 → 全部の順で当てる。

### 純粋関数のテストと、その手前の配線のテストは別もの(2026-08-31)

`NotificationPlan`(いつ何を出すか)は 純粋関数として手厚くテストしてあったが、
**`NotificationService.plannedNotifications`(DB から設定と大会を拾う配線)は無防備**だった。
`NotificationServiceTests` を新設(10 件)。守っているのは主に 2 つ:

- **過ぎた時刻には登録しない**(`notification.date > now`)—— この判定は
  `NotificationService` にしか無い。過去に予約すると即座に鳴る
- **大会を探す基準は「今」ではなく今日の 0 時**(`startOfDay`)—— 「今」にすると
  9 時開始の大会は昼に開いた時点で終了扱いになり、**その日の夜の振り返り通知が出ない**。
  大会当日は一度きりなので、逃すと振り返りが書かれないまま終わる

**「通知オフなら空」の門番は 3 か所ある**(`NotificationService` に 1 つ、
`NotificationPlan` の `plan` と `notification` に 1 つずつ)。1 つ 2 つ外しても
テストは通る —— 3 か所すべて外して初めて落ちる。**層ではなく約束のほうを固定している**ので
これで正しい(全部外れたら素の DB でも stale が 3 件漏れる)。

### 表示と判定は同じ「値」から作る(2026-09-05)

「できたが続いています」と出ているのに提案が出ない、を防ぐには
**同じ関数を呼ぶだけでは足りない**(引数の作り方が違えば答えが変わる)。
`MasteryStanding` という 1 つの値を作り、**画面の文も提案リストもそこから派生させる**。
構造上ずれようがない形にする。

**入力に意味を持たせるときは、コードで区別されているか確かめる。**
手応えは 3 択に見えて、`closer` と `next` はコード上まったく同じ扱いだった
(`done` の連続を切るだけ)。**画面に 3 つ並んでいることは、3 つの意味があることを保証しない。**
`grep` で「その値で分岐している箇所」を数えるのが早い。

### 連続回数を画面に出さない(2026-09-05)

「できたが 2 回続いています」は、次に「次にやる」を付けた瞬間に 0 になる。
CLAUDE.md が禁じたストリーク(途切れると離脱を招く)と同じ減衰体験になる。

**出すのは向きの 3 値だけ**(進んでいます / の段階です / 仕切り直しています)。
回数は判定の内部に閉じる。「あと 1 回で上がります」も同じ理由で出さない。
段名は本人が承認しないと変わらないので、文の主語が安定する。

### 提案の材料は「いまの段になってから」に切る(2026-09-05)

昇格を承認しても履歴は変わらないので、**全履歴を見ると次の保存で即座に再提案される**
(先頭の done×3 がそのまま残る)。`fetchFocusResultsSinceLevelChange` で
`level_change` の最後より後に**入力された**ぶんだけに切る。
基準が `practice_date` ではなく `created_at` なのは、過去日を選べるから ——
昇格後に過去日を入れると昇格前の証拠が混ざる。

### 格子(カレンダー)を組むときの制約(2026-09-04)

**スキルの対応表より `.build/checkouts` のソースを信じること。**
`~/.claude/skills/building-skip-ui/references/components.md` は `Grid` / `GridRow` を
「Full」と書いているが、ピン留めしている skip-ui 1.59.2 では**丸ごとコメントアウト**されている。

| 部品 | 可否 | 根拠 |
|---|---|---|
| `MultiDatePicker` | **不可** | `Controls/DatePicker.swift:334-563` が `/* */`。型が存在しない |
| `Grid` / `GridRow` | **不可** | `Containers/Grid.swift:60-1216` が `/* */`。使えるのは `GridItem` 型だけ |
| `LazyVGrid` を `List` の中に | **不可** | `Containers/LazyVGrid.swift:58-63` —— 自前でスクロールするので、親のスクロールを検知すると *nested scroll error を避けるため描画を中断*する |
| `.listRowInsets(_:)` | **不可** | `Containers/List.swift:1369` が `@available(*, unavailable)` |

- **格子は `VStack` + `HStack` で組む。** `List` の中に置くなら**格子全体を 1 行に収める** ——
  週ごとに行を分けると区切り線が格子の中に入り、列もずれる
- **行の左右 16dp は消せない**(`listRowInsets` が不可)。横に n 個並べる行は
  「画面幅 − 32」で設計する。360dp 端末で 7 列なら 1 列 46dp しかない
- **1 行に 7 個並べるセルは `.plain` + 自前の `.background` で組む。**
  Material のボタンは `ButtonDefaults.ContentPadding`(左右 24dp)と `defaultMinSize`(58dp)を
  持つので、`.bordered` 系だと 46dp の列に収まらない見込み(実測はしていない)。
  `.plain` は Android では「ラベルに `clickable` を貼るだけ」なので、
  **`.frame` がそのままタップ領域になる** —— カレンダーはこれで両 OS とも問題なく出た。
  ボタンが 2〜3 個の行(月送りなど)は `.bordered` のままで入る
- **等分するには `.frame(maxWidth: .infinity)` をボタンとラベルの両方に**付ける
  (`ChipStyle.swift` の踏み跡)。`minWidth` で固定すると小さい端末ではみ出す
- **押せないセルを `.disabled()` の Button にしない** —— VoiceOver が空振りの操作対象として
  読み上げる。押せないなら `Text` にする

### エミュレータの検証はビルドと並走させない(2026-09-04)

カレンダーを実装した直後、アプリが `ANR in com.tange.badnote`
(`Input dispatching timed out`)を起こした。コードを削って切り分けたが、
**最終的にどの変更とも相関しなかった** —— 同じコードで 3 回続けて再現しない。
ANR ログの `Load: 3.83 / 2.61 / 1.51` と、**先に Pixel Launcher 自身が ANR していた**ことから、
`xcodebuild` / Gradle と並走してエミュレータが飽和していたのが実態。

**`adb` で確認するときはビルドを止めてから。** ANR が出たら、まずコードを疑う前に
`logcat -c` してビルドの無い状態で 3 回試すこと(切り分けに 30 分使った)。

### Skip の落とし穴(実際に踏んだもの)

- **`DateFormatter.date(from:)` は Android だけ寛容** — `2026-13-45` を iOS は nil にするが、
  Android は **2027-02-14 に繰り上げて受け入れる**(2026-08-31 に `DayStamp.date(from:)` で踏んだ)。
  **書き戻して一致するかで確かめる**(`formatter.string(from: date) != text` なら nil)。
  ゼロ埋めしていない `2026-3-1` も同時に弾ける

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
  2026-08-24)。ファイル共有は不可。バックアップ(§11)は JSON 文字列をそのまま共有する
- **SkipSQL の `transaction` はネストできない** — BEGIN を二重発行して
  `cannot start a transaction within a transaction` になる。複数リポジトリの書き込みを
  1 つに畳むときは、内側を `createInCurrentTransaction` のようなトランザクションを
  開かない版にして、いちばん外だけで `db.transaction` する
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
