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

**画面** — ホーム(§7.1)/ 練習ログ入力(§7.2)/ 課題一覧(§7.4 の一部)/ 課題の登録・編集(§3)/ インボックス整理。

**実機での起動を確認済み**(2026-08-21)。`AppDatabase.open()` が Application Support に
DB を作る経路が実際に通ることを確認した。

---

## 0. 最優先

### タブアイコンが Android で表示されない

`ContentView` にテンプレート由来の `Label(_, systemImage:)` が 3 か所残っている。
SF Symbols は Android に無いため、`.symbolset` を用意して
`Image("name", bundle: .module)` に置き換える(`skip-icons` スキル)。

### テンプレート残骸の掃除

`WelcomeView` / `ItemListView` / `ViewModel.swift` / `Item` が未使用のまま残り、
Welcome・Settings タブがテンプレートのまま。タブ構成を決めて整理する。

---

## 1. Phase 1 に足りないもの

### 1.1 めざす姿の編集画面(§7.1)

**機能が欠落している。** `VisionRepository` は完成してテストも通っているが、
呼んでいるのはホームの表示だけで、**書き込む UI がどこにも無い**。
現状では「めざす姿」を登録する手段がゼロ。4 層構造の頂点なので最優先。

- テキストの編集
- 画像 1 枚(`vision.image_path`)の扱い
- 空のとき「数回使った後に 1 度だけ促す」(§7.1)。初回は促さない

### 1.2 課題詳細(§7.3)

画面ごと未着手。**表示に必要なデータはすべて揃っている。**

| 表示項目 | API |
|---|---|
| 累計時間 | `PracticeRepository.totalMinutes(issueId:)` |
| 重点にした回数 | `IssueRepository.focusSpanCount(issueId:)` |
| 再浮上回数 | `Issue.resurfaceCount` |
| 進み方(手応えの点) | `PracticeRepository.fetchFocusResults(issueId:)` ※日付も返す形への拡張が要る |
| レベル履歴 | `IssueRepository.fetchLevelChanges(issueId:)` |

未実装のロジック:

- 「克服した(定着確認へ)」は **Lv.4 のときだけ有効**。Lv.3 以下では理由を出す
- 「再浮上させる」はアーカイブ済みのときだけ表示。**レベルは前回の 1 つ下から再開**(ゼロに戻さない)
- 再浮上 3 回以上で「よく戻ってくる課題」バッジ
- レベルを下げる操作(「⋯」メニューの中に置く)

### 1.3 大会画面(§7.5)

画面 + テーブル 2 つ(`issue_competition` / `competition_review`)。
一覧は `fetchUpcoming(asOf:)` / `fetchFinished(asOf:)` がそのまま使える。

- 課題と大会の紐付け。**`both` の課題は両種目のセクションに出す**
- 習得コストと残り時間から「この大会では厳しいかもしれません」を控えめに提示
- 調整期の帯(`AdjustmentPeriod.nearestTarget` が大会名を返せる)
- 大会後の振り返り(種目ごとに 1 セット、3 つ目の回答から課題登録への導線)
- 終了した大会の記録。削除は「⋯」メニューの奥に置く

### 1.4 課題一覧の残り(§7.4)

タップによる層移動のみ実装済み。残り:

- 長押しドラッグ(層をまたぐ移動、層内の並び替え)
- 右スワイプで 1 段上げる / 左スワイプで 1 段下げる
- 週次の組み替えモード
- 絞り込み行 — タグは `fetch(tagId:)` があり、習熟度・種目のフィルタは未実装。**既定はフィルタなし**
- アーカイブ別画面(これまでに定着した課題)

### 1.5 通知(§8)

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

### Skip の落とし穴(実際に踏んだもの)

- **`sorted()` / `map` / `filter` の戻り値は変更不可** — `insert` / `append` すると Android だけ
  実行時に `UnsupportedOperationException`。新しい配列に写してから触る
- **`Int64` と `Int` リテラルの `==` / `!=` は Kotlin で通らない** — 比較演算子(`<` `>`)は通るので
  Swift 側では気づけない。`Int64(0)` のように型を揃える
- **`XCTUnwrap` の戻り値から型を辿れない** — `var x: Issue = try XCTUnwrap(...)` と明示する
- **`.keyboardType` は macOS で使えない** — `Package.swift` が macOS を宣言しているので
  `#if !os(macOS)` で囲む
- **アイコンは `.symbolset`** — `Image(systemName:)` は Android で描画されない
