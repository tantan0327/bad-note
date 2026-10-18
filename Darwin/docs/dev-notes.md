# 開発メモ

`tasks.md` から分離(2026-10-11)。実際に踏んだ落とし穴と、確認の手順。
残作業は `tasks.md`、デザインの決めごとは `design.md`。

---

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

### `skip app launch` が何も出さずに固まったら DerivedData を消す(2026-10-12 に踏んだ)

**症状** —— `skip app launch --ios` が 5 分経っても 10 分経っても何も出さない。
`xcodebuild` のプロセスは生きているのに CPU は 0%、`swift-frontend` も `clang` も
走っておらず、`.build` のどこにもファイルが書かれない。

**原因** —— `.build/Darwin/DerivedData/SourcePackages` が**依存の解決の途中で
壊れたまま残っていた**。前の実行を強制終了したのが発端で、以後の実行はそれを読んで
同じ地点で止まり続ける。**放っておいても解けない。**

**見分け方(推測せずこれで判定する)**

```
# 1. 進んでいるか —— ファイルが増えていなければ止まっている
find .build/Darwin/DerivedData -type f | wc -l   # 30 秒あけて 2 回
# 2. 最後に書かれた時刻 —— ずっと前なら、いまの実行は何もしていない
find .build/Darwin/DerivedData -type f -newermt "-2 minutes"
# 3. コンパイラが動いているか
pgrep -fl "swift-frontend|clang|XCBBuildService"
```

**ゾンビが残っていないかも見る。** 強制終了した `xcodebuild` が親を失って
`launchd`(ppid 1)にぶら下がったまま何日も生き残ることがある。

```
ps -eo pid,ppid,lstart,etime,args | grep xcodebuild
```

**復旧**

```
pkill -f "skip app launch"; pkill -f "xcodebuild -workspace"
rm -rf .build/Darwin/DerivedData          # ビルドキャッシュだけ。checkouts は消さない
# 先に解決だけ通して切り分ける(全体ビルドより早く結果が出る)
xcodebuild -workspace Project.xcworkspace -scheme "BadNote App" \
  -derivedDataPath .build/Darwin/DerivedData -resolvePackageDependencies
skip app launch --ios
```

`Conflicting identity for skip / skip-foundation / skip-unit` の警告は
**この固まりとは関係ない**(`source.skip.tools` と `github.com` の両方から
同じパッケージが来ているだけ)。解決自体は成功する。

### `gradle` は別途インストールが要る(2026-10-12 に踏んだ)

**症状** —— ビルドの最後の「Run skip gradle」フェーズだけが落ちる。

```
Error: An executable tool named 'gradle' could not be found in the PATH
```

`Android/gradle/wrapper/` にラッパーの設定はあるが、**Skip の `skip gradle` は
PATH の `gradle` を使う**ので、ラッパーだけでは足りない。

**確かめ方**

```
which gradle                 # 無ければこれ
ls /opt/homebrew/Cellar/gradle   # 無ければ本体ごと消えている(リンク切れではない)
brew list --versions gradle
```

**直し方** —— `brew install gradle`。

**`brew install maestro` は別物が入る**(2026-10-12 に踏んだ)—— homebrew の `maestro` は
**AI エージェントのデスクトップアプリ**(runmaestro.ai、820MB)で、UI テストの Maestro ではない。
UI テストのほうは公式タップから入れる。

```
brew tap mobile-dev-inc/tap
brew install mobile-dev-inc/tap/maestro
```

**実体の無いデーモンが残ることがある。** gradle を消しても `GradleDaemon` の
java プロセスは生き続ける(`/opt/homebrew/Cellar/gradle/<消えた版>/...` を指したまま)。
入れ直す前に落としておく。

```
pgrep -f GradleDaemon | xargs kill
```

**iOS だけ見たいときは飛ばせる** —— `SKIP_ACTION=none skip app launch --ios`。
ただし両 OS で動くのがこのアプリの前提なので、常用しない。

### 「Run skip gradle」はエミュレータが無ければ assemble に落ちる(2026-10-11 に直した)

元の Skip テンプレートは常に `gradle -p ../Android launchDebug` を走らせるので、
**Android の実機もエミュレータも無いと `installDebug` で必ず落ちていた**
(`No connected devices!`)。iOS だけ触っているときに `** BUILD FAILED **` と出て、
コードを疑って時間を使うことになる。

`Darwin/BadNote.xcodeproj` のビルドフェーズに **`adb devices` を見る分岐**を足した。

- つながっていれば従来どおり `launch`(ビルド → インストール → 起動)
- 無ければ `assemble`(APK を作るところまで)。**ビルドは成功で終わる**
- `offline` の端末は「無い」扱い(インストールに失敗するため)

判定は `adb devices` の 2 行目以降に `device` の行があるか。`adb` は
`$ANDROID_HOME/platform-tools/adb`、無ければ `PATH` から探す。

**両 OS のコンパイルはエミュレータなしで確認できる**(APK まで作るので)。
実機の挙動を見たいときだけエミュレータを起動する。

`SKIP_ACTION` でも制御できる(テンプレート由来)—— `none` で gradle を丸ごと飛ばす、
`assemble` で明示的にビルドのみ。

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

**既定タブはホーム**(`@AppStorage("tab")` で最後に開いたタブを覚えるので、前回別のタブで終えていれば
そのタブから始まる)。

iOS シミュレータは **画面を叩けない**(`simctl` にタップが無く、`osascript` は
補助アクセスが無いので System Events も使えない)。深い画面の見た目を確かめたいときは、
`ContentView.body` の先頭に一時的に

```swift
if true { return AnyView(PracticeLogView()) }
return AnyView(TabView(selection: $tab) { ... })
```

を入れてビルドし、`xcrun simctl io <UDID> screenshot` を撮ってから元に戻す。
**戻したあと `git diff` が空になることを必ず確認する。**

### 画面が固まったら `@Environment(\.dismiss)` を疑う(2026-10-19 に踏んだ)

**症状** —— 課題詳細から編集画面へ進もうとすると、押しても遷移せず、
ナビゲーションバーの文字が灰色のまま固まる。Maestro は
`Unable to perform work on main run loop, process main thread busy for 30.0s` と出す。

**原因** —— `IssueDetailView`(`NavigationLink` の行き先として押し込まれた画面)に
`@Environment(\.dismiss)` を宣言していた。**宣言しただけで起きる** ——
`dismiss()` を呼んでいなくても、`onAppear` でも `onChange` でも同じだった。

**直し方** —— 押し込まれた画面では使わない。自動で閉じたい場面があっても、
**本人が押して戻る形にする**。同じ結果をもっと確実に出せる。

**見つけ方** —— 1 コミットずつビルドして実機で開き直すのが速い。
`git revert --no-commit <疑うコミット>` → ビルド → Maestro、を繰り返す。
この件は「削除を足したコミット」を打ち消して初めて切り分けられた。

### `ForEach(0..<count)` は件数が減ると落ちる(2026-10-19 に踏んだ)

範囲をそのまま `ForEach` に渡すと、SwiftUI は**件数が変わらない前提**で保持する。
件数が減ると古い番号で配列を引き、`Array._checkSubscript` で落ちる。

```swift
ForEach(0..<model.progress.count, id: \.self) { ... }        // 落ちる
ForEach(Array(0..<model.progress.count), id: \.self) { ... }  // 配列にすれば動く
```

課題を削除して手応えの配列を空にしたときに踏んだ。**件数が動く配列では必ず `Array(...)` にする。**
クラッシュログは `~/Library/Logs/DiagnosticReports/BadNote-*.ips`。
`faultingThread` のフレームを見ると、どの View のどの `ForEach` かまで分かる。

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

### 理由の申告が要る API を数える(2026-10-11)

`PrivacyInfo.xcprivacy` に何を書くかは、**推測せずバイナリと `#if` を見て決める**。

- **アプリのコードを grep する** —— `UserDefaults` / `@AppStorage` /
  `fileModificationDate` / `creationDate` / `systemUptime` / `mach_absolute_time` /
  `volumeAvailableCapacity` / `activeInputModes`。
  `FileManager.createDirectory` は**対象外**(対象はタイムスタンプを読む API だけ)
- **依存ライブラリは `#if SKIP` を見る** —— `skip-foundation` の `FileManager.swift` は
  丸ごと `#if SKIP` なので **Android 側にしか入らない**。
  `FileAttributeKey.modificationDate` が grep に出ても iOS のバイナリには無い
- **決め手はビルドしたバイナリ** —— `strings .build/debug/libBadNote.dylib | grep NSUserDefaults` 。
  Apple が見るのもバイナリのシンボルなので、ここに出なければ申告は要らない

いま申告しているのは `NSPrivacyAccessedAPICategoryUserDefaults` / `CA92.1` の 1 つだけ。
**アップロードして ITMS-91053 のメールが来たら、そこに書かれたカテゴリを足す** ——
事前に全部盛りにしない(使っていない API を申告するのも誤り)。

`.app` に入ったかの確認:

```
find Darwin/build -name "PrivacyInfo.xcprivacy" -path "*.app/*"
```

### Maestro のフローの置き場と約束(2026-10-11)

`.maestro/` にフロー、出力は `Darwin/fastlane/screenshots/ja/`(fastlane の置き場に直接書く)。

- **`back` を使わない。** iOS と Android で挙動が違う。画面を戻したいときは
  `launchApp` で入れ直す —— タブは `@AppStorage("tab")` が覚えているので戻ってくる
- **`clearState: true` を使わない。** `@AppStorage` を持つアプリで
  Android が真っ白になる既知の条件に当たる。状態のリセットはアプリの中の操作でやる
- **文字列の照合は `.*X.*` の形で書く。** iOS は部分一致、Android は完全一致の
  正規表現なので、素の文字列だと片方で落ちる
- **タブは識別子で掴めるのが iOS だけ。** SkipUI は `NavigationBarItem` に
  独自の modifier を渡すので、`.tabItem` に付けた testTag が Android に届かない
  (`Containers/TabView.swift` の `NavigationBarItem(modifier: options.itemModifier(...))`)。
  Android で流すときは `tapOn: "課題"` のように文言で掴む
- **識別子の付け方はこのプロジェクトの流儀に合わせる** —— kebab-case の「画面-部品」
  (`home-record` / `tab-issues`)。スキルが例示する `button.foo` の形にはしない
  (既存の 160 個と揃わなくなる)

### Skip の落とし穴(実際に踏んだもの)

- **`DateFormatter.date(from:)` は Android だけ寛容** — `2026-13-45` を iOS は nil にするが、
  Android は **2027-02-14 に繰り上げて受け入れる**(2026-08-31 に `DayStamp.date(from:)` で踏んだ)。
  **書き戻して一致するかで確かめる**(`formatter.string(from: date) != text` なら nil)。
  ゼロ埋めしていない `2026-3-1` も同時に弾ける

- **`#if DEBUG` は Android では常に false**(2026-10-11 に確認)—— skipstone は
  `#else` の側だけを Kotlin に出す。**Debug ビルドでも false。**
  つまり `#if DEBUG` で囲んだコードは **iOS にしか存在しない**。
  デモデータの投入のような開発用の仕掛けを Android でも使いたいときは、
  別の口(フラグの受け渡しか、書き出した JSON の読み込み)が要る。
  リリースビルドに入れたくないものを囲む用途としては、iOS 側では正しく効く
- **`Double` に `Int` リテラルを入れられない**(2026-10-11 に踏んだ)——
  `let day: Double = 60 * 60 * 24` も `createdDaysAgo: Double = 0` も、
  `Double` の引数に `3` を渡すのも、Kotlin では
  `Initializer type mismatch: expected 'Double', actual 'Int'` で落ちる。
  **Swift 側のビルドと `swift test --filter` では気づけない** —— フルの `swift test` で初めて出る。
  `60.0` / `0.0` / `3.0` と小数で書く。`Date(timeIntervalSince1970:)` の引数も同じ
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
