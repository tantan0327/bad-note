# 仕様書

バドミントン競技者向け目標管理アプリ。
用語と実装上の制約は `CLAUDE.md` を参照。

---

## 1. 目的

解決する課題は 2 つ。

1. **忘れる** — コーチのアドバイスや試合の反省を忘れてしまう
2. **続かない** — モチベーションが持続しない

対象はバドミントン競技者(主に対戦型・個人視点)。
ダブルスの選手も使えるが、課題は必ず「自分の課題」として記述する。

- ✗ ローテーションの意思疎通ができていない(相手との共同課題)
- ○ 後ろに下がる判断を自分から先に出せている(自分の課題)

---

## 2. 基本構造

ゴールから降りてくる 4 層。

```
めざす姿(なりたい選手像)
   ↓ 大会に意味を与える
目標の大会(通過点・締め切り)
   ↓ 今やることが決まる
今週の重点 3 つ(完了形で書かれた課題)
   ↓ 意識できたかを記録
練習ログ(時間と手応え)
```

従来の「欠点を積み上げて潰す」構造ではなく、**上から降ろす**設計にする。

---

## 3. 中心概念

### 3.1 課題(Issue)

課題は 2 つの文を持つ。

| フィールド | 内容 | 例 |
|---|---|---|
| `coachWords` | 自分で気づいたこと、またはコーチに言われたことの原文。基本そのまま(誤入力の修正だけ編集できる。2026-08-24) | 「もっとラケット面、下向いてるよ」 |
| `doneForm` | 完了形の言い換え。UI の主表示 | 「レシーブでラケット面を立てて構えられている」 |

**入力時に `doneForm` を強制しない。** 練習後は `coachWords` の 1 行だけ入れられればよく、
言い換えは後日の整理フェーズで行う。

### 3.2 習熟度(MasteryLevel)

不確実性の低い順に 4 段階。

| Lv | 識別子 | UI 表示 |
|---|---|---|
| 1 | `solo` | 素振りでできる |
| 2 | `drill` | ノックでできる |
| 3 | `pattern` | パターン練習でできる |
| 4 | `match` | 試合で出せる |

UI 表示を「素振り」ではなく「素振りでできる」にするのは、練習ログの**種類**
(全体練習 / 個人練習 / ゲーム練習 / 筋トレ)と語彙が衝突するため。
名詞のままだと「その練習をやった」に読めてしまう。ここで表すのは到達している段階。

**自動でレベルを上げない。** 同じ課題で手応え `done` が 3 回連続したら、
練習ログ保存時に「Lv.3 に上げますか?」と 1 度だけ提案する。承認するのはユーザー。

レベルを下げる操作は課題詳細画面の「⋯」メニューの中に置く(日常操作ではないため)。

### 3.3 優先度(Tier)

| 識別子 | UI 表示 | 上限 |
|---|---|---|
| `focus` | 今週の重点 | **3 件** |
| `next` | 次にやる | なし |
| `someday` | いつか | なし |

各層の中は手動並び順(`sortOrder`)が既定。
自動ソート(影響度順、放置期間順、習熟度順)は**表示切り替えのみ**で、保存順序を変更しない。

### 3.4 影響度とコスト

- `impact`(影響度): 1〜3 — 試合の失点に直結するか
- `cost`(習得コスト): 1〜3 — 直るまでの時間

**数字は画面に出さない。** 1 と 3 のどちらが大きいのか画面から読み取れず、入力する側が迷う。
DB は 1〜3 で持ち、表示は言葉にする。

| 値 | 影響度 | 習得コスト |
|---|---|---|
| 1 | 小さい | すぐ直る |
| 2 | 中くらい | 少しかかる |
| 3 | 大きい | シーズン単位 |

「影響度 3 × コスト 1」の課題にバッジを出す。重点に入れるべき候補。
「影響度 3 × コスト 3」は大会に間に合わない可能性があり、シーズン単位の課題として扱う。

### 3.5 種目(Discipline)

課題は 3 値を持つ。

- `singles`
- `doubles`
- `both` ← **既定値**

技術課題の多くは種目を問わないため、`both` を既定にする。
2 択を強制すると分類が形骸化する。

---

## 4. 忘れ防止(このアプリの中核)

### 4.1 想定するケース

再浮上の主目的は**技術の劣化ではなく、意識からの消失**。

- コーチに言われたが、そのまま忘れた
- インボックスに入れたきり整理されず埋もれた ← **最頻**
- 重点から外れて、そのまま触れていない

### 4.2 判定条件

評価対象は `status IN ('inbox','active') AND tier != 'focus'` の課題。
`archived` と、現に `focus` にある課題は対象外。
以下のいずれかに該当する課題を `stale` とし、`reason` を 1 つ持たせる。

| `reason` | 条件 | 理由文の例 |
|---|---|---|
| `never_focused` | `focus_span` が 1 件も無く、`created_at` が `stale_days` 以上前 | 「4 週間、一度も重点に入っていません」 |
| `left_focus` | 最後に `focus` を外れた `left_at` 以降の練習件数が `stale_practice_count` 以上 | 「重点から外れて練習 6 回、触れていません」 |
| `no_update` | `updated_at` が `stale_days` 以上前 | 「3 週間、更新がありません」 |

- 複数該当時の理由表示は **`never_focused` > `left_focus` > `no_update`** の優先とする
  (`never_focused` が §4.1 の最頻ケース=インボックスに埋もれた課題)。
- 日付比較は SQLite の `julianday()`(全バージョンで使用可・json 関数ではない)、
  または ISO 8601 TEXT の辞書順比較で行う。
- **タイムスタンプは UTC の ISO 8601 で統一して保存する。**
  でないと `practice_date > left_at` の比較がずれる。

閾値は `app_meta` に初期値を持たせ、後で調整できるようにする
(初期値: `stale_days=21` / `stale_practice_count=6`)。
設定画面「しばらく触れていない課題」から変更できる(7〜90 日 / 1〜30 回。2026-08-24)。
次の週次評価(§4.3)から新しい閾値で判定される。

### 4.3 提示方法

**自動で優先度を書き換えない。候補として提示する。**

ホーム画面に「しばらく触れていない課題」セクションを常設(該当なしなら非表示)。
各項目に理由を添える。

> スマッシュのあと戻りが遅い
> 4 週間、一度も重点に入っていません

3 択で完結させる(別画面に飛ばさない)。各選択の副作用は次のとおり。

| 選択 | 動作 |
|---|---|
| 今週の重点にする | `focus` 3 枠に空きがあれば `tier=focus`(`focus_span` を open + `last_focused_at` 更新)、`resurface_count += 1`、`stale_flag` を削除。埋まっていれば §7.4 の入れ替えフローへ回す |
| まだいい | `stale_flag` を削除するのみ(翌週また該当し得る。これは許容) |
| もう不要 | `status=archived`, `archived_at=now`, `stale_flag` を削除 |

判定は**週 1 回**のみ実行(重点を組み替えるタイミング、日曜夜など)。
毎日出すと無視されるようになる。

**実行ゲートと結果の保持**

- 判定結果は週次スナップショットとして `stale_flag` テーブルに保存し、
  次の評価まで固定表示する。ホーム表示は `stale_flag` の単純な SELECT。
- 起動時、`今日の曜日 == reshuffle_weekday`(既定 0=日) かつ
  `stale_last_evaluated_at` が今日より前なら評価を実行する。
  最後の評価から 7 日以上経過していれば曜日に関係なく実行する(取りこぼし救済)。
- 評価実行時は `stale_flag` を全削除してから再 INSERT する。
- 実行状態と閾値・組み替え曜日は `app_meta`(KVS)に持つ。

### 4.4 調整期の抑制

**直近の目標大会の 2 週間前に入ったら、stale の提示を停止する。**
大会直前に忘れていた課題を掘り返さない。

- 判定は「最も近い目標大会」の `event_date - now ≤ 14 日` で行う(§7.5 と共通)。
- 調整期に入っている間は**評価自体をスキップし、ホームのセクションも非表示**にする。

---

## 5. モチベーション設計

### 5.1 表示の切り替え

目標大会の **8 週間前**を境に、ホームの主数値を切り替える。

| 時期 | 大きく出す | 小さく添える |
|---|---|---|
| 8 週間より前 | 今月の練習時間 / レベルアップ回数 | 残り日数 |
| 8 週間以内 | 残り日数 / 残り練習回数 | 積み上げ |

同じデータで見せ方だけ変える。遠い時期に日数を大きく出すと「まだ先だ」になり逆効果。

### 5.2 残り練習回数

`残り日数 × 直近の平均練習頻度` から推定する。
日数より行動に直結する。

### 5.3 やらないこと

- **ストリーク(連続日数)** — 途切れたときに離脱を招く
- **課題の総数表示** — 増えるほどプレッシャーになる
- **未整理件数のバッジ** — 開くたびに宿題を突きつける形になる

未整理の課題は、練習ログ保存直後にのみ「3 件が未整理です。いま整理しますか?」と 1 度聞く。

---

## 6. データモデル

日付・時刻は ISO 8601 の TEXT で保持する。
**json 関数を使わない。**配列は必ず中間テーブルにする。

```sql
-- めざす姿(1 レコードのみ)
CREATE TABLE vision (
  id          INTEGER PRIMARY KEY,
  body        TEXT NOT NULL DEFAULT '',
  image_path  TEXT,
  updated_at  TEXT NOT NULL
);

-- 大会
CREATE TABLE competition (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  name        TEXT NOT NULL,
  event_date  TEXT NOT NULL,
  venue       TEXT,
  created_at  TEXT NOT NULL
);

-- 大会のエントリー種目(1 大会が複数種目を持てる)
CREATE TABLE competition_entry (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  competition_id INTEGER NOT NULL REFERENCES competition(id) ON DELETE CASCADE,
  discipline     TEXT NOT NULL,          -- 'singles' | 'doubles'
  is_target      INTEGER NOT NULL DEFAULT 0,  -- 種目ごとの目標大会フラグ
  UNIQUE (competition_id, discipline)
);
-- 制約: is_target = 1 は discipline ごとに最大 1 件(アプリ側で担保)

-- 課題
CREATE TABLE issue (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  coach_words     TEXT NOT NULL,
  done_form       TEXT,                  -- 未整理なら NULL
  coach_name      TEXT,
  discipline      TEXT NOT NULL DEFAULT 'both',   -- 'singles'|'doubles'|'both'
  mastery_level   INTEGER NOT NULL DEFAULT 1,     -- 1..4
  tier            TEXT NOT NULL DEFAULT 'someday',-- 'focus'|'next'|'someday'
  sort_order      INTEGER NOT NULL DEFAULT 0,
  impact          INTEGER,               -- 1..3
  cost            INTEGER,               -- 1..3
  status          TEXT NOT NULL DEFAULT 'inbox',  -- 'inbox'|'active'|'archived'
  resurface_count INTEGER NOT NULL DEFAULT 0,
  last_focused_at TEXT,
  created_at      TEXT NOT NULL,
  updated_at      TEXT NOT NULL,
  archived_at     TEXT
);

-- タグ(ショット種別など)
CREATE TABLE tag (
  id    INTEGER PRIMARY KEY AUTOINCREMENT,
  name  TEXT NOT NULL UNIQUE
);

CREATE TABLE issue_tag (
  issue_id INTEGER NOT NULL REFERENCES issue(id) ON DELETE CASCADE,
  tag_id   INTEGER NOT NULL REFERENCES tag(id) ON DELETE CASCADE,
  PRIMARY KEY (issue_id, tag_id)
);

-- 課題と大会の紐付け
CREATE TABLE issue_competition (
  issue_id       INTEGER NOT NULL REFERENCES issue(id) ON DELETE CASCADE,
  competition_id INTEGER NOT NULL REFERENCES competition(id) ON DELETE CASCADE,
  PRIMARY KEY (issue_id, competition_id)
);

-- 練習ログ
CREATE TABLE practice (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  practice_date TEXT NOT NULL,
  minutes       INTEGER NOT NULL DEFAULT 0,
  kind          TEXT,        -- 'whole'|'individual'|'game'|'strength'
  created_at    TEXT NOT NULL
);

-- 手応え(練習ログ × 重点課題)
CREATE TABLE focus_record (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  practice_id INTEGER NOT NULL REFERENCES practice(id) ON DELETE CASCADE,
  issue_id    INTEGER NOT NULL REFERENCES issue(id) ON DELETE CASCADE,
  result      TEXT,        -- 'done'|'closer'|'next' / NULL は未入力
  UNIQUE (practice_id, issue_id)
);

-- 習熟度の変更履歴
CREATE TABLE level_change (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  issue_id   INTEGER NOT NULL REFERENCES issue(id) ON DELETE CASCADE,
  from_level INTEGER NOT NULL,
  to_level   INTEGER NOT NULL,
  created_at TEXT NOT NULL
);

-- focus 在籍履歴(stale 条件② と §7.3「重点にした回数」を賄う)
CREATE TABLE focus_span (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  issue_id   INTEGER NOT NULL REFERENCES issue(id) ON DELETE CASCADE,
  entered_at TEXT NOT NULL,
  left_at    TEXT                 -- NULL = 現在 focus 中
);
-- 運用: tier を focus にする時に 1 行 INSERT(left_at=NULL)、
--       focus から外す時に開いている span の left_at を now で UPDATE。
--       重点にした回数 = COUNT(*)、未 focus = NOT EXISTS。

-- stale 週次スナップショット(3 択処理で 1 行ずつ消す)
CREATE TABLE stale_flag (
  issue_id     INTEGER PRIMARY KEY REFERENCES issue(id) ON DELETE CASCADE,
  reason       TEXT NOT NULL,      -- 'never_focused'|'left_focus'|'no_update'
  evaluated_at TEXT NOT NULL
);

-- 設定・メタ(閾値・組み替え曜日・前回評価日時)
CREATE TABLE app_meta (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
-- 初期値: stale_days=21 / stale_practice_count=6 /
--         reshuffle_weekday=0(日) / stale_last_evaluated_at=''

-- 大会後の振り返り(種目ごとに 1 件)
CREATE TABLE competition_review (
  id                INTEGER PRIMARY KEY AUTOINCREMENT,
  competition_id    INTEGER NOT NULL REFERENCES competition(id) ON DELETE CASCADE,
  discipline        TEXT NOT NULL,
  result            TEXT,   -- 戦績・自由記述
  went_well         TEXT,   -- うまくいったこと
  next_action       TEXT,   -- 次にやること
  needed_resources  TEXT,   -- 必要なもの(人・道具・情報)
  created_at        TEXT NOT NULL,
  UNIQUE (competition_id, discipline)
);
```

### 課題ごとの累計時間

保持せず、集計で求める。

```sql
SELECT SUM(p.minutes)
FROM focus_record f
JOIN practice p ON p.id = f.practice_id
WHERE f.issue_id = ?;
```

---

## 7. 画面仕様

全 5 画面。

### 7.1 ホーム

上から順に。

1. **めざす姿** — テキスト(+任意で画像 1 枚)。常設。カウントダウンより上
2. **カウントダウン** — 種目ごとにカード。近いほうを上に大きく
   ```
   シングルス  県大会     あと 42日 / 12回
   ダブルス    地区大会   あと 98日 / 28回
   ```
   時期による表示切り替えは**種目ごとに独立**
3. **今週の重点** — カード 3 枚。`doneForm`、習熟度(ミニ 4 分割バー)、直近の手応え。スクロールなしで 3 つ見えること。
   3 件に満たない分は**空き枠**として見せる(空き枠が「あと選べる」の合図。押すと組み替えモードへ)。
   見出しに `1/3` を添える(一覧側と同じ表記)
4. **しばらく触れていない課題** — 該当時のみ。理由付き。3 択をその場で完結
5. **積み上げ** — 通算の練習時間を大きく(減らない数字)。押すと積み上げ画面(§10.5)へ。
   通算 0 のときは大きな「0分」を出さず、静かな案内文にする
6. **練習を記録するボタン** — 末尾に大きく

**未登録時の扱い**

- 大会未登録 → 「大会を登録する」を表示。ただし大会なしでもアプリは成立させる
- めざす姿が空 → 初回は促さない。数回使った後に 1 度だけ促す
- 課題も練習も無い初回 → 重点の空きを「課題を書く」への誘導にする(2026-08-24)。
  課題か練習が 1 つできたら通常表示に戻る。めざす姿は促さないまま

### 7.2 練習ログ入力

ヘッダー: ✕ / 練習を記録 / 保存

1. **日付** — 今日が既定
2. **練習時間** — 大きい数字 + `+15分` `+30分` `+60分` チップ + リセット。直接入力も可
3. **種類** — 全体練習 / 個人練習 / ゲーム練習 / 筋トレ(単一選択)
4. **今週の重点** — カード 3 枚。各カードに 3 択セグメント(できた / 近づいた / 次にやる)
5. **追加する課題(任意)** — テキスト 1 行 + 「＋ もう 1 件追加」

**設計判断**

- 全項目任意。手応え未選択でも保存できる
- キーボードが必要なのは「時間」と「追加する課題」だけ
- ここで課題を整理させない(タグ・優先度・言い換えは別画面)
- スクロールは 1 画面半以内に収める
- 保存後に「90 分を記録しました / 今月の累計 14 時間」を短く表示。無言で閉じない
- 過去日付を選んだ場合も**現在の重点 3 つ**を表示する(履歴は持たない割り切り)
- 休養日は記録しない(種類に「休養」を作らない)

### 7.3 課題詳細

1. **できている状態** — 最上部に大きく
2. **習熟度** — 横 4 分割のバー(埋まった数 = 現在のレベル)+ 現在の段階名 +
   「〜に上げる」ボタン
3. **もとの言葉** — 原文。引用の見た目。コーチ名と日付
4. **記録** — 累計時間 / 重点にした回数 / 再浮上回数。
   数字はカードに載せ、積み上げ画面と同じ形(`StatItem`)
5. **進み方** — 手応えの履歴を色分けした点で時系列表示。文字にしない
6. **アクション**
   - 「克服した(定着確認へ)」 — **Lv.4 のときだけ有効**
   - 「再浮上させる」 — アーカイブ済みのときだけ表示
7. **属性** — タグ、影響度、コスト、Tier(折りたたみ)。
   日常で使わないのでいちばん下(「克服した」を折り返しの外に沈めない)

**設計判断**

- Lv.3 以下で「克服した」を押したら「まだ試合で出せていません」と理由を出す
- 再浮上時、レベルは前回の 1 つ下から再開(ゼロに戻さない)
- 再浮上 3 回以上で「よく戻ってくる課題」バッジ。弱点の本質を示す情報として提示

### 7.4 課題一覧

3 層を縦に並べたセクションリスト(タブにしない。移動先が見えている必要がある)。

```
今週の重点  3/3
次にやる    8件
いつか      14件
```

**優先順位の変更方法(3 つとも実装)**

1. **長押しドラッグ** — 層をまたぐ移動、層内の並び替え
2. **右スワイプで 1 段上げる / 左スワイプで 1 段下げる** — 一覧を眺めながら次々に仕分ける用途に最速
3. **週次の組み替えモード** — 重点 3 枠に対してタップで選ぶ専用モード

スワイプとドラッグは画面から見えないので、絞り込み行の下に常設の注記を添える
(「行は長押しで並び替え、左右スワイプで層の上げ下げができます」。2026-08-24)。

**重点が 3 枠埋まっているとき**

4 つ目を上げようとしたら「どれと入れ替えますか?」と現在の 3 つを提示。
押した 1 つが `next` に降りる。拒否だけで終わらせない。

**絞り込み**

上部に 1 行。ショットタグ / 習熟度 / 種目。
**既定はフィルタなし**(絞ると、もう一方の種目が視界から消えて忘れられる)。

**未整理(inbox)は末尾のセクションに出す**(2026-08-24)

練習ログで書いた 1 行が「書いたのに見つからない」とならないよう、
層の下に「未整理 N件」のセクションを置く(件数表記は層見出しと同じ形。タブのバッジにしない §5.3)。
行は原文 + 日付。層には混ぜない —— 整理はインボックス整理(「整理する」)を通す。

**アーカイブは別画面**

定着した課題は一覧に出さない。設定または大会画面から「これまでに定着した課題」として閲覧。
達成の記録として気持ちよく見える画面にする。

### 7.5 大会

**一覧** — これからの大会を日付順、下に終了した大会。目標大会にはバッジ(文字の星にしない)。

**詳細**

1. **基本情報** — 名前、日付、会場、種目。残り日数 / 残り練習回数
2. **この大会までに** — 種目ごとにセクション分け。`both` の課題は両方に出す
   - 習得コストと残り時間から「この大会では厳しいかもしれません」を控えめに提示
3. **調整期の帯** — 2 週間前から表示。stale 提示も停止
4. **大会後の振り返り** — 当日を過ぎるとフォームに切り替わる。**種目ごとに 1 セット**
   - 結果
   - うまくいったことは何か
   - 理想の姿に近づくために次にやることは何か
   - そのために必要なもの(人・道具・情報)は何か
   - 3 つ目の回答からそのまま課題を登録できる導線
   - 通知は**大会当日の夜に 1 回**
5. **終了した大会の記録** — 削除は「⋯」メニューの奥。気軽に消せる場所に置かない

**種目ごとに目標大会が異なる場合**

- 目標大会は `competition_entry.is_target` で種目ごとに指定
- 表示切り替え(8 週間)は種目ごとに独立
- **調整期の判定だけは「最も近い目標大会」を基準にする**(全体として調整期とする)
- 大会終了後、その種目の目標が空になったら「次の目標大会を設定しますか」と促す

---

## 8. 通知

**1 日 1 通まで。** 通知過多でオフにされると、忘れ防止の仕組みごと機能しなくなる。

| タイミング | 内容 |
|---|---|
| 練習開始前(曜日・時間帯で設定) | 今週の重点 3 つ |
| 大会当日の夜 | 振り返りを促す |
| 週 1 回(組み替えの曜日) | しばらく触れていない課題 |

時刻の指定は「時:分」(`DatePicker`)。分まで保存する(2026-08-23)。

---

## 9. Phase 分け

### Phase 1

- めざす姿 + 大会カウントダウン(種目ごと、8 週前で表示切替)
- 課題: 原文 + できている状態 / 習熟度 4 段階 / 3 層優先度 / 影響度・コスト / タグ / 種目区分
- 課題一覧: ドラッグ・スワイプ・組み替えモード / 種目フィルタ
- 練習ログ: 時間、種類、重点 3 つの手応え
- しばらく触れていない課題の提示(週 1 回、ホームに常設)
- 大会: 複数種目、種目ごとの課題セクションと振り返り
- 練習前リマインド
- 手動の再浮上

### Phase 2 以降

- 定着確認の間隔ロジック(練習回数ベースで 3 回パス → 定着)
- 投資期間フラグ(新技術を試合投入した直後、記録を成績集計から外す)
- 大会 1 週間前に、その大会で過去に出た課題を表示
- 対戦相手ごとの記録
- ホーム画面ウィジェット(iOS は SwiftUI、Android は Kotlin で個別実装)
- ペア対応(`pair_id` を nullable で追加する形で拡張可能)
- 深掘り枠(今月の 1 つ + 言い換えログ)
- 崩れの記録(連続失点の最大値、立て直しまでのポイント数)

---

## 10. 家でのトレーニング(家トレ)

Phase 1 の後に追加した機能(2026-08-22 決定)。練習ログ(§7.2)が「1 回の練習」を
**後から**記録するのに対し、家トレは「今日これをやる」という**前向きの毎日のリスト**。
タブの 2 番目に置く(ホーム / **家トレ** / 課題 / 大会)。

### 10.1 概念

- **メニュー**(`TrainingMenu`) — 繰り返しやる決めごと(素振り 50 回 / 体幹 10 分 …)。
  目安の分数を持てる(任意)
- **実施記録**(`TrainingLog`) — 日 × メニューで 1 行。チェックした事実と、
  チェック時点の分数の写し

### 10.2 画面

- その日のメニュー一覧。行をタップでチェック、もう一度タップで取り消し
  (押し間違いは必ず起きる)
- 日付を選べば昨日以前もさかのぼって付けられる(忘れた日が永久に空かないように)。
  画面の顔は「今日」の見出し。さかのぼりは「昨日」チップ +「別の日」の日付選択(2026-08-24)
- **チェックが付いた分だけの合計を出す。未達の数(残り N 件)は出さない**(§5.3)
- メニューの管理(追加 / 編集 / 並び替え / アーカイブ)は別画面。
  メニューは削除ではなく**アーカイブ**(過去の実施記録を守る)。
  アーカイブ済みは一覧末尾の折りたたみから**戻せる**(2026-08-24)。
  目安の分数は入力を**勧める**が必須にしない(§5.3 入力は任意)
- 曜日ごとの既定メニューは持たない(要ると分かってから足す)

### 10.3 積み上げへの合算

家トレの分数は練習時間の積み上げに**合算する**。ただし `practice` に行は入れない
(練習ログの一覧・編集に家トレが混ざり、編集で壊せてしまうため)。合算は集計側で行う:

- **集計の入り口は `StatsRepository.totalMinutes(from:to:)` の 1 つだけ。**
  `practice` と `training_log` を合算して返す。画面の累計はすべてここから取る
- `PracticeRepository.totalMinutes(from:to:)` は「練習ログだけ」の意味で残す(種類別の内訳用)
- チェック時にメニューの分数を `training_log.minutes` へ**写して固定する**。
  後からメニューの目安を直しても過去の積み上げは変わらない。
  分数の無いメニューは 0 分として入る

### 10.4 テーブル

```sql
-- 繰り返し使うメニュー
CREATE TABLE training_menu (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  name        TEXT NOT NULL,
  minutes     INTEGER,                        -- 目安。任意なので NULL 可
  sort_order  INTEGER NOT NULL DEFAULT 0,
  is_archived INTEGER NOT NULL DEFAULT 0,
  created_at  TEXT NOT NULL
);

-- 日ごとの実施記録。1 日 × 1 メニューで 1 行
CREATE TABLE training_log (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  menu_id       INTEGER NOT NULL REFERENCES training_menu(id) ON DELETE CASCADE,
  training_date TEXT NOT NULL,
  minutes       INTEGER,                      -- チェック時に menu からコピー。NULL 可
  done_at       TEXT,                         -- NULL = まだ
  UNIQUE (menu_id, training_date)
);
```

`training_date` は**ローカルの暦日**の TEXT(`2026-08-22`)。「その日やったか」の単位が
暦日だから。`practice_date`(UTC の ISO 8601 タイムスタンプ)とは形式が違う。

### 10.5 積み上げ画面

2026-08-23 に追加。ホームの「積み上げ」カードから開く。§5 モチベーション設計の延長で、
**「開くたびに必ず増えている」数字を主役に据え、自信の裏づけにする**画面。

出すもの(上から):

- **通算** — 全期間の合計練習時間。この画面の主役。**分まで出す**(1 回の練習で必ず桁が動き、
  増えたことが分かる)。開いたときに 0 から現在値へカウントアップする。**減らない数字**
- **上達・克服** — 通算のレベルアップ回数(§5.1)と定着した課題数(§7.4)を主役の下に併記。
  時間だけでなく「上手くなった / 乗り越えた」を出して自信につなげる
- **とどいた節目** — 到達済みの節目(1 / 5 / 10 / 25 / 50 / 100 / 200 / 500 / 1000 時間)を祝う。
  さらに **究極の目標 = 1 万時間(1 万時間の法則)** を北極星として常設する。
  **到達済みだけを祝い、次の節目までの残り時間や締め切りは出さない**(§5.3)。
  前向きの目標ではなく後ろ向きの達成の記録として扱う。
  **このセクションは最初の節目(1 時間)に到達してから出す**(§7.1「初回は促さない」の精神。
  0 時間の人に遠い 1 万時間だけを見せない。初登場そのものを最初のご褒美にする)
- **月ごとの時間** — 直近 6 か月の縦棒。**今月は進行中**として強調し、短くても下降に見せない。
  記録が 0 の月も細く残す(空白は「途切れ」に見え、§5.3 の罠になる)
- **種類の内訳** — 種類ごとの合計(全体練習 / 個人練習 / ゲーム練習 / 筋トレ + 家トレ + 未選択)。
  記録のある区分は必ず見える太さで出す

合算・集計はすべて §10.3 の `StatsRepository` を通す(累計をここ以外で足さない)。

**§5.3 との線引き(この画面で外すと逆効果)** — 見せるのは「合計」だけ。ストリーク・
日ごとのカレンダー / ヒートマップ・目標値やノルマ(「あと N 時間」)・平均・前月比は出さない。

---

## 11. 実装順序

1. Skip プロジェクトの雛形、iOS / Android 両方で起動確認
2. **SkipSQL で CRUD だけの検証画面**(最大の関門)
3. 練習ログ入力画面
4. ホーム画面
5. 課題一覧 / 課題詳細 / 大会画面

3 と 4 ができた時点で 1〜2 週間実際に使い、仕様を見直してから残りに進む。
