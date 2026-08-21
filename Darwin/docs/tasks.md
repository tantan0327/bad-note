# タスク

`spec.md` のうち、何ができていて何が残っているか。
最終更新: 2026-08-21

---

## 現状

テスト 347 本。iOS / Android(Robolectric)の両方でパス。両プラットフォームでビルド成功。

**データ層** — Repository は 5 つとも完成(`Issue` / `Practice` / `Competition` / `Vision` / `Tag`)。
加えて `AppMeta` / `StaleFlag` / `StaleEvaluator`。

**テーブル** — マイグレーション 8 本で 12 テーブル。未作成は `issue_competition` と `competition_review` の 2 つ。

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

**画面** — ホーム(§7.1)/ 練習ログ入力(§7.2)/ 課題一覧(§7.4 の一部)/ 課題の登録・編集(§3)/
インボックス整理 / めざす姿の編集(§7.1、テキストのみ)/ 大会一覧・登録(§7.5 の一部)/
課題詳細(§7.3)/ 週次の組み替えモード(§7.4)/ アーカイブ(§7.4)。

**課題一覧**(§7.4)は、タップによる層移動・**スワイプ(右で 1 段上げ / 左で 1 段下げ)**・
**絞り込み行**(種目 / 習熟度 / タグ、既定はフィルタなし)まで実装済み。
種目の絞り込みは `both` の課題も含める(§3.5)。

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

## 1. Phase 1 に足りないもの

### 1.1 めざす姿の画像(2026-08-21 時点で残っているのはこれだけ)

テキストの編集と「数回使った後に 1 度だけ促す」は実装済み
(`VisionEditView` / `VisionPrompt`)。**残るのは画像 1 枚(`vision.image_path`)。**

**`PhotosPicker` は SkipUI 非対応。** 列と読み書きはあるが、画像を選ぶ手段が Android に無い。
実装するなら次のどちらか。

1. iOS は `PhotosPicker`、Android は `#if SKIP` + Compose の `PickVisualMedia` を自前で書く。
   content URI をアプリ領域にコピーする処理も要る
2. 画像はあきらめる。§7.1 も「+**任意**で画像 1 枚」で、主役はテキスト

優先度は低い。画像が無くてもアプリは成立する。

### 1.2 大会の詳細と振り返り(§7.5)

一覧と登録は実装済み(`CompetitionListView` / `CompetitionEditView`)。
**残るのは詳細画面**と、テーブル 2 つ(`issue_competition` / `competition_review`)。

- 詳細の基本情報(残り日数 / 残り練習回数)
- 課題と大会の紐付け。**`both` の課題は両種目のセクションに出す**
- 習得コストと残り時間から「この大会では厳しいかもしれません」を控えめに提示
- 調整期の帯(`AdjustmentPeriod.nearestTarget` が大会名を返せる)
- 大会後の振り返り(種目ごとに 1 セット、3 つ目の回答から課題登録への導線)
- 終了した大会の記録。削除は「⋯」メニューの奥に置く

### 1.3 長押しドラッグ(§7.4 の残り)

スワイプ・組み替えモード・絞り込み行・アーカイブ画面は実装済み(2026-08-21)。
**残るのは長押しドラッグ(層をまたぐ移動、層内の並び替え)だけ。**

**素直には書けない。** SwiftUI の `onMove` はひとつの `ForEach` の中でしか働かないので、
3 層をまたぐドラッグはそのままでは表現できない。取り得る方針:

1. 3 層を 1 つの `ForEach` に統合し、セクションの境界を自前で管理する
   (行に「どの層のどこか」を持たせ、`onMove` の移動先インデックスから層を逆算する)
2. Android は `#if SKIP` で Compose のドラッグを書き、iOS は `onMove` で書く
3. **作らない。** スワイプと組み替えモードで仕分けは足りており、
   §7.4 が 3 つの方法を挙げているのは「移動手段が 1 つだと詰まる」ためで、
   既に 2 つある。実際に使ってドラッグが要ると感じてから作る

着手前に方針を決めること。

### 1.4 通知(§8)

全部未実装。`StaleEvaluator` はアプリを開いたときにしか走らないため、
**忘れ防止の起点がユーザーの起動に依存している。** §4 が中核である以上ここは Phase 1 の必須項目。

| タイミング | 内容 |
|---|---|
| 練習開始前(曜日・時間帯で設定) | 今週の重点 3 つ |
| 大会当日の夜 | 振り返りを促す |
| 週 1 回(組み替えの曜日) | しばらく触れていない課題 |

**1 日 1 通まで。**

---

## 2. 判断が要る宿題

- **課題一覧が `active` のみ** — `inbox` の課題は整理画面を通らない限りどこにも出ない。
  `IssueListModel.statuses` を変えれば出せるが、「一覧は整理済みだけ」という設計を維持するかの判断
- **練習ログとコーチの言葉が別トランザクション** — Repository が別なので、
  練習は保存されたが課題登録が失敗する並びが理論上あり得る
- **DB 接続がモデルごと** — 画面が増えるほど接続が増える。共有の置き場所を決める時期
- **ローカライズ** — `Localizable.xcstrings` に日本語がキーとして入っている。
  英語対応するなら早いほうが楽

---

## 3. Phase 2(§9)

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

### 実機の DB を覗く

```
adb -s emulator-5554 shell "run-as com.tange.badnote sqlite3 files/badnote.sqlite 'PRAGMA user_version;'"
adb -s emulator-5554 shell "run-as com.tange.badnote sqlite3 files/badnote.sqlite 'SELECT key, value FROM app_meta;'"
```

`user_version` が `migrations` の本数と一致していればスキーマは最新。

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
  `#if !os(macOS)` で囲む
- **アイコンは `.symbolset`** — `Image(systemName:)` は Android で描画されない
  (ただし `heart.fill` / `house.fill` / `gearshape.fill` など約 50 個は SkipUI が
  Material Icons に対応付けるため表示される。対応表は SkipUI の実装なので依存しない方が安全)
- **`setFoo(...)` という名前のメソッドは `var foo` と衝突する** — Kotlin では `var foo` が
  `setFoo()` を生成するため、同名のメソッドを書くと
  `Platform declaration clash: ... same JVM signature` になる。
  Swift 側では通るので Android のコンパイルまで気づけない。`selectFoo(...)` のように改名する
- **`PhotosPicker` は使えない** — `UIViewRepresentable` / `TimelineView` / `matchedGeometryEffect` も同様。
  `building-skip-ui` スキルの `references/components.md` の "Not Available in SkipUI" を先に見る
