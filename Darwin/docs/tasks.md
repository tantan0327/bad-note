# タスク

**ゴール: 2026 年 10 月中に App Store へ公開する。Google Play は後回し(時期未定)。**

最終更新: 2026-10-11

このファイルは**残っている作業だけ**を持つ。何が出来ていてどう作るかの決めごとは
`design.md`、Skip の落とし穴や確認手順は `dev-notes.md`、仕様は `spec.md`
(2026-10-11 に 1 ファイルから 3 つに分けた。完了したタスクは消す。履歴は git log)。

アプリとして作るものは終わっている(2026-09-05 以降コードの変更なし)。
2026-10-11 に確認: `swift test` は iOS / Android(Robolectric、JUnit 690 本)とも全部パス、
`skip verify` も通る、`Localizable.xcstrings` はコードと同期済み。
Apple Developer Program は加入済み。
残っているのは **App Store への配信の準備**と、配信前に直しておきたい **UI/UX の細部**。

Android のビルドとテストは引き続き通し続ける(両 OS で動くのがこのアプリの前提)が、
**Play への配信作業は §6 に寄せて、今月は手を付けない**。

---

## 0. 今月のスケジュール

| 週 | 期間 | やること | 終わった印 |
|---|---|---|---|
| 1 | 10/11(土)〜 10/17(金) | §1.1 置き場 / §1.2 ポリシー公開 / §1.3 申告 / §2 の「リリース前」/ §1.4 デモデータと撮影 | スクショ 5〜6 枚が揃い、`swift test` → `skip verify` が通る |
| 2 | 10/18(土)〜 10/24(金) | §1.5 リリースビルドと TestFlight / §1.6 App Store Connect の登録 / **10/24(金)までに審査提出** | TestFlight で実機確認済み。審査待ち |
| 3 | 10/25(土)〜 10/31(土) | 審査の指摘対応 / 公開 / §1.7 公開後の後始末 | App Store で公開 |

審査は通常 1〜3 日だが、初回は指摘で差し戻されることが多い。**10/24 提出なら 1 往復ぶんの余裕がある**。
10/28 を過ぎて未提出なら、§2 の残りを切って先に出す。

---

## 1. App Store への配信に残っている作業

### 1.1 置き場(週 1 の最初に)

- [x] GitHub に `tantan0327/bad-note`(public)を作って push 済み(2026-10-11)。
      リモートは HTTPS + `gh` の認証(SSH 鍵は未登録)。`record` は `main` に取り込み済みで、
      **リリースは `main` から切る**。以後の作業は `main` で進めてよい

### 1.2 プライバシーポリシーの公開

- [ ] `docs/privacy.md` を GitHub Pages で `https://tantan0327.github.io/bad-note/privacy.html` に出す
      (リポジトリの Settings → Pages → `main` / `docs`。`privacy.md` は Jekyll が HTML にする。
      `permalink: /privacy.html` を front matter に足すと URL が固定できる)
- [ ] `Darwin/fastlane/metadata/{ja,en-US}/privacy_url.txt` の URL が実際に開くことを確認
      (ブラウザで 200 が返るまで `skip meta index` へ進まない)
- [ ] 最終更新日を公開日に直す(今は 2026 年 8 月 25 日)

### 1.3 iOS 側の申告

- [ ] **`PrivacyInfo.xcprivacy` を追加する** —— `ContentView.swift:14` の `@AppStorage("tab")` は
      `UserDefaults` なので Apple の「理由の申告が要る API」に当たる。
      無いとアップロード後に ITMS-91053 の警告メールが来て、審査で弾かれる。
      `Darwin/` に置いて Xcode のターゲットに含め、
      `NSPrivacyAccessedAPICategoryUserDefaults` / 理由 `CA92.1`、
      `NSPrivacyTracking = false`、`NSPrivacyCollectedDataTypes = []` を書く
- [ ] App Store Connect のプライバシー質問は「データを収集しない」で回答
- [ ] 年齢レーティングの質問票(すべて「なし」で 4+)
- [ ] `ITSAppUsesNonExemptEncryption = false` は `Info.plist` に済み(確認のみ)

### 1.4 デモデータとストアのスクリーンショット

fastlane のテキストは済み。**画像が 1 枚も無い。**

- [ ] **見映えのするデモデータを入れる手段を決める** —— 実データのままでは撮れない。
      候補: (a) `ExportRepository` の JSON を手で作って読み込む経路を一時的に足す /
      (b) `#if DEBUG` でデモ投入ボタンを設定に出す(リリースビルドには入らない)。
      (b) のほうが Maestro から再現しやすく、あとで Play 用に撮り直すときも使い回せる
- [ ] 撮る画面を 5〜6 枚に絞る: ホーム(カウントダウン + 重点 3 枚 + 積み上げ)/ 家トレ /
      課題一覧の 3 層 / しばらく触れていない課題の 3 択 / 積み上げの節目 / 大会のねらい
- [ ] `Darwin/fastlane/screenshots/ja/N_ja.png`(iPhone 6.7" 1290×2796。
      ディレクトリ自体がまだ無い。iPad 対応は宣言していないので iPhone だけでよい)
- [ ] 手順は `skip-ui-automation` スキル(Maestro + `skip app launch`)。
      Maestro のフローはまだ 1 本も無いので、撮影用の 1 本から書く。
      iOS シミュレータは `simctl` で画面を叩けないので、Maestro が唯一の自動化手段
- [ ] 撮ったあとデモデータを消す

### 1.5 リリースビルドと TestFlight

- [ ] 出荷前の順序を通す: `swift test` → `skip verify` → `skip meta index` → `skip export -c release`
      (`skip meta index` は `APPLE_APP_STORE_ID` が要るので §1.6 の登録を先に)
- [ ] Xcode の Archive → App Store Connect へアップロード(署名は自動管理のまま)
- [ ] TestFlight の内部テストで**実機**に入れて一通り触る —— 通知の許可ダイアログ /
      新規インストールでの DB 作成 / 週次評価の初回 / 長押しドラッグ(`adb` でも
      シミュレータでも再現できない。指で確かめる)
- [ ] 既存データがある端末で**上書きインストール**して起動する(マイグレーションの実地確認)

### 1.6 App Store Connect の登録と提出

- [ ] App Store Connect にアプリを作り、`Skip.env` の `APPLE_APP_STORE_ID` を埋める
- [ ] リスティングは fastlane の `Darwin/fastlane/metadata/{ja,en-US}/` の内容を入れる
      (`en-US` は UI が日本語のみである旨を冒頭に書いてある。そのまま)
- [ ] 審査メモに「アカウント不要・通信なし・すべて端末内」と、
      通知が練習予定日と大会に紐づくこと(何もしないと鳴らない)を書いておく。
      審査員が通知を試せないと「機能しない」と誤解されやすい
- [ ] **10/24(金)までに審査に出す**

### 1.7 公開後

- [ ] `README.md` のスクリーンショット欄(TODO コメント)を外して画像を貼る
- [ ] `design.md` の「現状」のテスト本数と日付を更新する
- [ ] `Skip.env` の `CURRENT_PROJECT_VERSION` を次回のために 2 に上げる

---
## 2. UI/UX —— リリース前に直す(週 1)

2026-10-11 に View 全 21 ファイルを `design.md` の決めごとと照らして洗い直した結果。
**決めごとどおりの箇所と、§4 で見送ると決めたものは除いてある。**
どれも半日以内で、ロジックの変更を伴わない(テストは `canSave` の分だけ足す)。
**直したら iOS だけでなく Android のビルドも通す**(両 OS で動くのがこのアプリの前提)。

- [ ] **空の練習ログが保存できてしまう** —— `View/PracticeLogModel.swift` に `canSave` が無く、
      0 分・種類なし・手応えなしでも保存が通る。しかも練習ログは**後から直せない**
      (`PracticeRepository.delete` を呼ぶ View がゼロ)ので、0 分の行が積み上げと回数に残る。
      → 他の Model と同じ `canSave`(分数 0 かつ種類なしなら無効)。テストを 1 本足す
- [ ] **練習ログのシートを下スワイプで閉じると入力が無言で消える** —— `View/HomeView.swift:50`。
      時間・手応え 3 件・追加課題を入れた後のワンジェスチャで全部失う。
      → 入力があるときだけ `.interactiveDismissDisabled(true)`、✕ に確認ダイアログ
- [ ] **課題タブの初回が「まだありません」だけで次の 1 手が無い** —— `View/IssueListView.swift:239`。
      ホーム・大会・家トレは `EmptyStateView` + ボタンを出しているのにここだけ無く、
      並べる行が無いのに「長押しで並び替え…」の注記だけ常設で出る。
      → `EmptyStateView(icon: "checklist")` +「課題を書く」。注記は行があるときだけ
- [ ] **数字入力のキーボードを閉じる手段が無い** —— `View/PracticeLogView.swift:249`、
      `View/TrainingView.swift:216`、`View/TrainingMenuFormView.swift:33`。`numberPad` には改行が無く、
      `FocusState` / `onSubmit` がリポジトリ全体でゼロ。+15 分チップがキーボードの裏に隠れる。
      → `ToolbarItemGroup(placement: .keyboard)` に「完了」(SkipUI の対応を先に確認。
      不可なら `FocusState` で背景タップで閉じる)
- [ ] **保存できない理由が押した場所から見えない** —— 課題の登録(`View/IssueEditView.swift:18`)と
      大会の登録(`View/CompetitionListView.swift:129`)は、エラー文が画面最上部にだけ出る。
      下までスクロールしてツールバーの保存を押すと**何も起きなかったように見える**。
      → `canSave` で保存を `.disabled` にし、理由は該当欄の直下に出す(家トレのメニュー編集は
      すでに `.disabled` だが理由が出ない。`View/TrainingMenuFormView.swift:49` にも footer を 1 行)
- [ ] **カレンダーの「登録済みの日」が VoiceOver に伝わらない** —— `View/PracticePlanView.swift:313`。
      ラベルは日付だけで、予定日かどうかは塗りにしか無い。残り回数の根拠になる画面。
      → `.accessibilityValue` に「登録済み / 未登録」
- [ ] **大会の登録フォームに `accessibilityIdentifier` が無い** —— `View/CompetitionListView.swift:138`
      以降の大会名・開催日・会場・Toggle 4 つ(保存だけ付いている)。インボックス整理の
      種目・影響度・コスト・タグ(`View/InboxTriageView.swift:94` 以降)も同じ。
      スクショ撮影の Maestro フロー(§1.4)が通れない。
      → `competition-edit-name` / `triage-discipline-*` のように命名規則どおり付与
- [ ] **めざす姿の保存の identifier が Button ではなく Text に付いている** ——
      `View/VisionEditView.swift:56`。他の保存ボタンと非対称で Maestro から掴めない。→ Button 側へ移す
- [ ] **通知画面を開いた瞬間に OS の許可ダイアログが出る** ——
      `View/NotificationSettingsView.swift:150`(トグルを入れる前に要求)。拒否してもトグルは入り、
      「許可されていないので届きません」が出ない。審査でも「文脈の無い許可要求」は指摘されやすい。
      → トグルを ON にしたときに要求し、拒否状態を 1 行で出す
- [ ] **設定にプライバシーポリシーの行を足す** —— `ContentView.swift:127` はバージョン表示だけ。
      §1.2 で公開した URL への `Link` を 1 行(審査の要件ではないが、聞かれたとき答えが要る)

## 3. UI/UX —— リリース後でよい

- [ ] **初回ホームに同格の主ボタンが 3 つ並ぶ** —— `View/HomeView.swift:206 / 288 / 503`
      (大会を登録する / 課題を書く / 練習を記録する)が全部 `.borderedProminent`。
      → 使い始めは「課題を書く」だけ prominent にし、他は `.bordered`
- [ ] **装飾アイコンが VoiceOver に読まれる** —— `View/EmptyStateView.swift:26`、
      `View/StatsView.swift:95`、`View/PracticeLogView.swift:147`。→ `.accessibilityHidden(true)`
- [ ] **振り返りの「保存しました」が画面最上部に出る** —— `View/CompetitionDetailView.swift:25`
      に対して保存ボタンは `:341`。→ カードの中にインラインで出す
- [ ] **課題を削除する手段が無い** —— `IssueRepository.delete` を呼ぶのはインボックス整理だけ。
      誤登録は「克服した」でアーカイブして逃がすしかない。→ 編集画面の末尾に削除(確認付き)
- [ ] **エラー文の色が直書き** —— `foregroundStyle(.red)` が 21 か所。「View で色を直書きしない」の
      唯一の抜け。→ `Palette.error` を足して置き換え(ダークでの赤も同時に決める)
- [ ] **文字の段階表に無いサイズ** —— `View/StatsView.swift:103`(40pt)、`:293`(9pt。
      Dynamic Type で拡大しない)、`View/PracticePlanView.swift:337` の `Color.white` 直書き。
      → 表に足すか `.caption2` / トークンに寄せる
- [ ] **アプリアイコンを静かなトーンに合わせる** —— 今の `AppIcon.png` は黒 × 青の光沢に
      英語のタグライン「TRAIN. ANALYZE. IMPROVE.」と「BADNOTE」の文字が入っていて、
      ブランド色(インディゴ)とも、日本語だけの UI とも合っていない。60px では文字が潰れる。
      → 文字なし・単色面 + 1 モチーフに作り直し、`skip icon` で両 OS と Play 用 512px を一括生成。
      **リリースを止めるほどではない**が、ストアで最初に見られるのはこれ
- [ ] `BadNoteApp.swift:18` のテンプレートのログ文言(「Skip app logs are viewable…」)を消す
- [ ] `Localizable.xcstrings` は 242 キーすべて翻訳なし(`sourceLanguage: en` でキーが日本語)。
      日本語専用のうちは無害。英語対応するときに `Text(verbatim:)` の日本語 + 数値
      (`HomeView` / `RemainingText` / `StatsView`)もまとめて直す

---

## 4. やらないと決めたこと

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
- **書き出した JSON の読み込み(復元)** — `ShareLink` がテキスト共有のみで、
  ファイルの受け取りに両 OS の自前実装が要る。`View/ExportView.swift:67` に明記済み(2026-10-11 確認)
- **初回のチュートリアル画面** — 各タブの空状態 + ボタンで足りる(§2 の課題タブの空状態で揃う)

---

## 5. Phase 2(§9)

- 家トレのリマインド通知(§8 の「1 日 1 通」の制約との整理が必要なので Phase 2 送り)
- 定着確認の間隔ロジック(練習回数ベースで 3 回パス → 定着)
- 投資期間フラグ
- 大会 1 週間前に、その大会で過去に出た課題を表示
- 対戦相手ごとの記録
- ホーム画面ウィジェット
- ペア対応(`pair_id` を nullable で追加)
- 深掘り枠(今月の 1 つ + 言い換えログ)
- 崩れの記録
- 英語対応(`Localizable.xcstrings` の翻訳 + `displayName` 系の素の String)

---

## 6. Google Play への配信(時期未定。今月は手を付けない)

iOS を出してから。Android のビルドと Robolectric のテストは今後も毎回通す。

- [ ] **Play デベロッパーアカウントの種別を確認する** —— 2023-11-13 以降に作った**個人**アカウントは、
      製品版へ出す前に **12 人以上のテスターで 14 日間連続のクローズドテスト**が要る。
      該当するなら、配信の 3 週間前にはテスターの当てをつけてクローズドテストを始める
- [ ] Android の署名鍵を作る: `Android/app/keystore.jks` + `keystore.properties`
      (どちらも .gitignore 済み。**鍵は 1Password などに別途保管** —— 失うと更新が出せない)
- [ ] **`AndroidManifest.xml` の `INTERNET` 権限を外す** —— テンプレートの残り。
      通信ゼロを謳うポリシーとデータセーフティの申告に対して、権限だけ持っているのは説明がつかない。
      外したあとエミュレータで起動・通知・書き出しを一通り確認(iOS 配信前にやっても害は無い)
- [ ] スクショ: `Android/fastlane/metadata/android/ja-JP/images/phoneScreenshots/N_ja-JP.png`
      (§1.4 のデモデータと Maestro フローを使い回す)
- [ ] Play 専用の画像: `images/icon.png`(512×512)と `featureGraphic.png`(1024×500)
- [ ] Play Console にアプリを作り `Skip.env` の `GOOGLE_PLAY_STORE_ID`(= `com.tange.badnote`)を有効にする
- [ ] データセーフティは「収集なし・共有なし」。年齢レーティングの質問票
- [ ] `skip export -c release` で AAB を作り、内部テスト → (クローズドテスト →)製品版
- [ ] リリースビルド(ProGuard あり)を実機で一通り触る —— Debug と挙動が変わりうるのは Android だけ
