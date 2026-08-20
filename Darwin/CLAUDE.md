# CLAUDE.md

このファイルはプロジェクト直下に置く。Claude Code は作業開始時に必ずこれを読むこと。
詳細な仕様は `docs/spec.md` を参照。

---

## プロジェクト概要

バドミントン競技者向けの目標管理アプリ。解決する課題は 2 つ。

1. コーチのアドバイスや試合の反省を忘れてしまう
2. モチベーションが持続しない

個人の課題に集中する設計。ペア(ダブルスの相方)の管理機能は持たない。

---

## 技術スタック

| 項目 | 選択 |
|---|---|
| フレームワーク | Skip (https://skip.dev) |
| 言語 | Swift / SwiftUI |
| Android 出力 | Kotlin / Jetpack Compose(Skip が変換) |
| 永続化 | SkipSQL(SQLite に直接 SQL を発行) |
| IDE | Xcode |
| 対象 | iOS(主)、Android(将来配布) |

---

## 絶対に守る制約

### 使ってはいけないもの

- **SwiftData** — Skip 非対応。使わない
- **Core Data** — Skip 非対応。使わない
- **SQLite の json 関数** — SQLite 3.38 以降の機能。Android 14 未満 / iOS 16 未満で失敗する
- **配列や辞書を 1 カラムに詰める設計** — タグなどは必ず中間テーブルにする
- **`position: fixed` 相当の画面外レイアウト** — 該当なしだが、Android で崩れる指定に注意

### Skip 非対応 API について

Skip は比較的新しいツールで、学習データに情報が少ない。
**iOS では動くが Android で動かない API** を書いてしまうリスクが高い。

- 迷ったら推測せず、https://skip.dev/docs/ を確認する
- 標準的な SwiftUI コンポーネント(List, Form, NavigationStack, Button, TextField, Picker など)を優先する
- 凝った描画や新しめの API を使う前に、Skip の対応状況を確認する

### ディレクトリの役割

- `Sources/AppName/` — **両プラットフォームに変換される場所。アプリのコードはここに書く**
- `Darwin/Sources/` — iOS 固有の足場。基本触らない
- `Android/app/src/main/` — Android 固有の足場。基本触らない

---

## アーキテクチャ方針

### レイヤ構成

```
View (SwiftUI)
  ↓
ViewModel / Store
  ↓
Repository  ← SQL はここにだけ書く
  ↓
SkipSQL (SQLContext)
```

**View から直接 SQL を呼ばない。** 将来 swift-sqlcipher や SwiftData 対応に乗り換える可能性があるため、
永続化の詳細は Repository の内側に閉じ込める。

### Repository 一覧

- `IssueRepository`
- `PracticeRepository`
- `CompetitionRepository`
- `VisionRepository`
- `TagRepository`

### スキーマ管理

SkipSQL のバージョンベースのマイグレーション機能を使う。
スキーマ変更時は必ずマイグレーションを書く。既存 DB を壊さないこと。

---

## 用語集

**この用語を必ず使うこと。** `Task` `Goal` `Todo` などの一般名で書かないこと。

| 日本語(UI 表示) | 識別子 | 意味 |
|---|---|---|
| めざす姿 | `Vision` | 大会の上位にある、なりたい選手像。1 レコードのみ |
| 大会 | `Competition` | 目標とする試合 |
| 種目 | `Discipline` | `singles` / `doubles` |
| 目標大会 | `targetCompetition` | 種目ごとに 1 つ指定される大会 |
| 課題 | `Issue` | 克服対象。このアプリの中心概念 |
| コーチの言葉 | `coachWords` | 言われたことの原文。編集しない |
| できている状態 | `doneForm` | 課題を完了形で言い換えたもの。UI の主表示 |
| 習熟度 | `MasteryLevel` | 1〜4。下記参照 |
| 優先度の層 | `Tier` | `focus`(今週の重点) / `next`(次にやる) / `someday`(いつか) |
| 今週の重点 | `focus` | 最大 3 件 |
| 練習ログ | `Practice` | 1 回の練習の記録 |
| 手応え | `FocusRecord` | 練習ログ内での、重点課題ごとの結果 |
| 影響度 | `impact` | 1〜3 |
| 習得コスト | `cost` | 1〜3 |
| しばらく触れていない | `stale` | 忘れかけの課題。再浮上の対象 |

### 習熟度 4 段階

| Lv | 識別子 | UI 表示 |
|---|---|---|
| 1 | `solo` | 素振り |
| 2 | `drill` | ノック |
| 3 | `pattern` | パターン練習 |
| 4 | `match` | 試合 |

### 手応え 3 段階

| 識別子 | UI 表示 |
|---|---|
| `done` | できた |
| `closer` | 近づいた |
| `next` | 次にやる |

**「×」「失敗」「未達」という語を UI に出さないこと。** モチベーション設計上の意図的な選択。

---

## UI の原則

- **数字は積み上げ側だけ出す。** 累計練習時間、レベルアップ回数、定着した課題数は出す。未処理件数や課題総数は出さない
- **ストリーク(連続日数)は実装しない。** 途切れたときに離脱を招く
- **アプリは解釈や警告を出さない。** 判断材料を提示し、判断は本人に任せる
- **入力項目は原則すべて任意。** 必須項目を増やすと記録されなくなる
- **練習ログ入力画面では課題を整理させない。** タイトル 1 行の登録まで

---

## テスト方針

TDD で進める。実装より先にテストを書く。

- テストは XCTest で書く。Skip が JUnit に変換し、両プラットフォームで走る
- Android 側は既定で Robolectric(エミュレータ不要)
- `#if os(Android)` は Robolectric 下で false。
  Android 系すべてを対象にするなら `#if os(Android) || ROBOLECTRIC`
- 片方の環境で除外したい場合は XCTSkip を使う
- XCTAssert の失敗時、Swift は続行し Kotlin は停止する。
  1 テストにアサーションを詰め込みすぎない
- Repository のテストは SQLContext(path: nil) のインメモリ DB を使う

### テストを厚くする対象
stale 判定 / レベルアップ提案 / 重点 3 枠の入れ替え /
残り練習回数の推定 / 調整期の判定 / 時間の按分集計

### テストしない対象
SwiftUI の View(手で確認する)

## 開発フロー

1. 実装したら **iOS シミュレータと Android エミュレータの両方でビルドを通す**
2. iOS で動いても Android で落ちることがある。片方だけの確認で完了としない
3. DB 変更を伴う場合は、既存データがある状態での起動を確認する

Skip 固有の実装は、~/.claude/skills/ に導入済みの Skip 公式スキルに従うこと。
推測で書かず、必ずスキルと https://skip.dev/docs/ を確認する。

---

## Claude への依頼の粒度

大きすぎる依頼は品質が落ちる。以下の粒度で進める。

- 良い: 「`IssueRepository` を作る。CRUD と tier による絞り込みのみ。スキーマは docs/spec.md 参照」
- 良い: 「練習ログ入力画面の SwiftUI を作る。データ層は `PracticeRepository` を使う」
- 悪い: 「Phase 1 を実装して」

---

## 実装の順序

1. Skip プロジェクトの雛形作成、iOS / Android 両方で起動確認
2. **SkipSQL で CRUD だけの検証画面**(← 最大の関門。ここが通らなければ技術選定を見直す)
3. 練習ログ入力画面
4. ホーム画面
5. 課題一覧 / 課題詳細 / 大会画面

## その他メモ
ロジック層は可能な限り純粋関数として書く。
Repository を引数に取らず、必要なデータを受け取る形にする。

