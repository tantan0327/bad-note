# タスク

`spec.md` のうち、何ができていて何が残っているか。
最終更新: 2026-08-21

---

## 現状

テスト 428 本。iOS / Android(Robolectric)の両方でパス。両プラットフォームでビルド成功。

**データ層** — Repository は 5 つとも完成(`Issue` / `Practice` / `Competition` / `Vision` / `Tag`)。
加えて `AppMeta` / `StaleFlag` / `StaleEvaluator`。

**テーブル** — マイグレーション 9 本で §6 のテーブルはすべて作成済み。

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
通知設定(§8)。

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

**タブ構成**(2026-08-21 決定) — **ホーム / 課題 / 大会** の 3 つ。
タブは「往復するもの」だけに絞る。

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

## 1. App Store に出すために要るもの

**Phase 1 の機能は揃っている**(§7 の全 5 画面 / §4 の週次評価 / §8 の通知)。
ここから先は「出せる状態」にする作業。

### 1.1 アプリアイコン

**テンプレートのまま。** `Darwin/Assets.xcassets/AppIcon.appiconset/` は `Contents.json` だけ、
Android の `mipmap-*` も無い。**アイコンが無いと申請できない。**

```
skip icon --background "#5C6BC0" symbol.svg
```

iOS と Android の両方を 1 コマンドで生成できる(`skip-icons` スキル)。元絵が要る。

### 1.2 ストアのメタデータとスクリーンショット

`Skip.env` は `PRODUCT_NAME = BadNote` / `com.tange.badnote` のまま。決めるもの:

- 表示名(日本語のストア名)、サブタイトル、説明文、キーワード、カテゴリ、年齢レーティング
- **スクリーンショット** — 端末サイズごとに必要。`skip-ui-automation` スキルの
  Maestro + `skip app launch` で撮る手順がある
- **プライバシー情報** — このアプリは**通信もデータ収集もしない**ので「収集なし」で通る。
  ただしプライバシーポリシーの URL は要求される
- 置き場は `Darwin/fastlane/metadata/` と `Android/fastlane/metadata/android/`
  (`skip-localization` スキルにディレクトリ構成とバイト数の上限がある)

### 1.3 データの書き出し

**今このアプリはデータが消えたら終わる。** 数か月分の練習ログと課題が
端末の `badnote.sqlite` にしか無い。iCloud バックアップの対象ではあるが、
**ユーザーが自分で吸い出す手段が無い。**

配信するなら、せめて 1 つは用意したい。

1. 書き出し(JSON か CSV を共有シートで出す)—— 最小。`ShareLink` は SkipUI 対応済み
2. 読み込み(機種変更時の復元)
3. iCloud / Google Drive 同期 —— Phase 2 以降

---

## 2. 毎日触る所の摩擦(実機で確認済み)

効果の大きい順。**すべて実機のスクリーンショットで確認した実在の問題。**

### 2.1 種類のチップが折り返して崩れる

`全体練習` が「全体練 習」と 2 行に割れている(4 つを 1 行に詰めているため)。
**練習時間の `リセット` も同じ理由で「リセッ ト」に割れている。** どちらも Android だけ。
2 行に分ける、`.lineLimit(1)` + `.minimumScaleFactor`、横スクロールのいずれか。

### 2.2 通知時刻の指定が −/+ ボタン

1 時間ずつ押す作りで、18 時 → 7 時に変えるのに 11 回押す。
`DatePicker(displayedComponents: .hourAndMinute)` が素直
(SkipUI 対応済み。§8 は時刻の指定方法まで決めていない)。

### 2.3 重点の空き枠が見えない

ホームは重点が 1 件だと 1 枚しか出ない。§7.1 は「カード 3 枚」「スクロールなしで
3 つ見える」と書いており、**空き枠が見えること自体が「あと 2 つ選べる」の合図**になる。
一覧側は `1/3` と出るのにホームには無い。

---

## 3. 迷わせない工夫

### 3.1 初回起動で何をすればいいか分からない

入れた直後のホームは「めざす姿(まだ書かれていません)/ 大会を登録する / 重点はまだ
決まっていません / 練習を記録する」。**何から始めるかの順序が示されていない。**

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

## 4. 品質の土台

### 4.1 アクセシビリティが手つかず

- **`accessibilityIdentifier` が 0 件。** Maestro の UI テストが書けない
  (`skip-ui-automation` スキルは「すべての操作可能な View に付ける」としている)
- `accessibilityLabel` は設定の歯車のみ。アイコンだけのボタンに要る
- Dynamic Type(文字を大きくしたとき)未確認。大きい数字や 1 行チップが崩れやすい
- 進み方の点は**色だけで手応えを区別している**。色覚特性のある人に伝わらない

### 4.2 ダークモードの詰め

破綻はしていない(2026-08-22 に Android で確認)。ただしカードの背景が
`Color.secondary.opacity(0.1)` で、暗い地の上ではほとんど沈む。
`Material` や `.background(.regularMaterial)` などに寄せる余地がある。

### 4.3 ローカライズの抽出が動いていない

`Localizable.xcstrings` が実際の文字列に追いついていない(2026-08-22 時点で 99 キー)。
`SWIFT_EMIT_LOC_STRINGS = YES` はアプリターゲットに付いているが、文字列は SwiftPM 側の
`BadNote` モジュールにあるため、コマンドラインの `xcodebuild` では新しいキーが抽出されない。
カタログに無いキーはキー自体(=日本語)が出るので**動作に支障は無い**。
日本語のみで出すなら実害は無いが、英語対応の前に直す必要がある。

### 4.4 DB 接続がモデルごと

**実際に `database is locked` を踏んだ**(2026-08-22、通知設定の保存時)。
設定を書いている最中に別の接続を開いたのが原因。通知まわりは
「DB を使う部分(同期)」と「OS に登録する部分(非同期・DB を触らない)」に分けて回避したが、
**接続を共有していないという根本は残っている**。
インメモリ DB のテストでは接続が 1 本なので再現しない。実機でしか出ない。

**練習ログとコーチの言葉が別トランザクション**(Repository が別)も同じ章の宿題。

---

## やらないと決めたこと

- **めざす姿の画像**(§7.1「+任意で画像 1 枚」)— 2026-08-22 に見送り。
  `PhotosPicker` が SkipUI 非対応で、iOS と Android の両方に自前実装が要る割に、
  テキストがあれば成立する
- **長押しドラッグ以外の並び替え手段の追加** — スワイプ / ドラッグ / 組み替えモードの
  3 つで足りている

---

## 5. Phase 2(§9)

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

### Skip の落とし穴(実際に踏んだもの)

- **`sorted()` / `map` / `filter` の戻り値は変更不可** — `insert` / `append` すると Android だけ
  実行時に `UnsupportedOperationException`。新しい配列に写してから触る
- **`Int64` と `Int` リテラルの `==` / `!=` は Kotlin で通らない** — 比較演算子(`<` `>`)は通るので
  Swift 側では気づけない。`Int64(0)` のように型を揃える
- **`XCTUnwrap` の戻り値から型を辿れない** — `var x: Issue = try XCTUnwrap(...)` と明示する
- **`.keyboardType` は macOS で使えない** — `Package.swift` が macOS を宣言しているので
  `#if` で囲む必要がある。ただし **`#if !os(macOS)` と書くと Skip が Android 側でも中身を落とす。**
  ビルドは通り、Android で数字キーボードの代わりにフルキーボードが出て初めて気づく。
  `#if os(iOS) || os(Android)` と対象 OS を並べて書く(2026-08-22)
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
- **`PhotosPicker` は使えない** — `UIViewRepresentable` / `TimelineView` / `matchedGeometryEffect` も同様。
  `building-skip-ui` スキルの `references/components.md` の "Not Available in SkipUI" を先に見る
