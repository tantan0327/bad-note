import SwiftUI
import SkipSQL

enum ContentTab: String, Hashable {
    case home, training, issues, competitions
}

/// タブは「往復するもの」だけ。ホーム / 家トレ / 課題 / 大会 の 4 つ。
///
/// - **家トレ**(§10)は毎日開く画面なのでホームの隣(2 番目)
/// - **練習ログ入力**(§7.2)はホームのボタンからシートで開く(ヘッダーが ✕ / 保存 のモーダル)
/// - **課題詳細**(§7.3)は課題一覧からプッシュ
/// - **設定**は日常操作ではないのでホームのツールバーに置く
struct ContentView: View {
    @AppStorage("tab") var tab = ContentTab.home

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label {
                    Text("ホーム", bundle: .module, comment: "home tab label")
                } icon: {
                    Image("home", bundle: .module)
                }
                // Maestro がタブを掴むための識別子。**iOS にしか効かない** ——
                // SkipUI は `NavigationBarItem` に独自の modifier を渡すので、
                // Android のタブバーにはここの testTag が届かない(`dev-notes.md`)
                .accessibilityIdentifier("tab-home")
            }
            .tag(ContentTab.home)

            NavigationStack {
                TrainingView()
            }
            .tabItem {
                Label {
                    Text("家トレ", bundle: .module, comment: "training tab label")
                } icon: {
                    Image("fitness_center", bundle: .module)
                }
                // Maestro がタブを掴むための識別子。**iOS にしか効かない** ——
                // SkipUI は `NavigationBarItem` に独自の modifier を渡すので、
                // Android のタブバーにはここの testTag が届かない(`dev-notes.md`)
                .accessibilityIdentifier("tab-training")
            }
            .tag(ContentTab.training)

            NavigationStack {
                IssueListView()
            }
            .tabItem {
                Label {
                    Text("課題", bundle: .module, comment: "issues tab label")
                } icon: {
                    Image("checklist", bundle: .module)
                }
                // Maestro がタブを掴むための識別子。**iOS にしか効かない** ——
                // SkipUI は `NavigationBarItem` に独自の modifier を渡すので、
                // Android のタブバーにはここの testTag が届かない(`dev-notes.md`)
                .accessibilityIdentifier("tab-issues")
            }
            .tag(ContentTab.issues)

            NavigationStack {
                CompetitionListView()
            }
            .tabItem {
                Label {
                    Text("大会", bundle: .module, comment: "competitions tab label")
                } icon: {
                    Image("emoji_events", bundle: .module)
                }
                // Maestro がタブを掴むための識別子。**iOS にしか効かない** ——
                // SkipUI は `NavigationBarItem` に独自の modifier を渡すので、
                // Android のタブバーにはここの testTag が届かない(`dev-notes.md`)
                .accessibilityIdentifier("tab-competitions")
            }
            .tag(ContentTab.competitions)
        }
    }
}

/// 設定(§4.2 の閾値、§8 の通知、アーカイブ閲覧の置き場)。
///
/// 日常操作ではないので、ホームのツールバーから開く。
struct SettingsView: View {
    // ストアのスクリーンショット用。**リリースビルドには入らない**(`Data/DemoData.swift`)
    #if DEBUG
    @State private var isShowingDemoWipeConfirmation = false
    @State private var demoErrorText: String? = nil
    #endif

    var body: some View {
        Form {
            // 上から「設定するもの」→「眺めるもの」の順(2.6)。
            // 練習予定日は残り練習回数(§5.2)と練習前の通知(§8)の両方を支えるので通知より前
            NavigationLink {
                PracticePlanView()
            } label: {
                Label {
                    Text("練習予定日", bundle: .module)
                } icon: {
                    Image("calendar_month", bundle: .module)
                }
            }
            .accessibilityIdentifier("settings-practice-plan")
            NavigationLink {
                NotificationSettingsView()
            } label: {
                Label {
                    Text("通知", bundle: .module)
                } icon: {
                    Image("notifications", bundle: .module)
                }
            }
            .accessibilityIdentifier("settings-notifications")
            NavigationLink {
                StaleSettingsView()
            } label: {
                Label {
                    Text("しばらく触れていない課題", bundle: .module)
                } icon: {
                    Image("history", bundle: .module)
                }
            }
            .accessibilityIdentifier("settings-stale")
            // ホームのカードは月 1 回しか出ず、「またにする」を押すと 30 日先になる。
            // **自分から始められる入口がここに無いと、その間どこからも入れない**
            NavigationLink {
                IssueReviewView()
            } label: {
                Label {
                    Text("課題の棚卸し", bundle: .module)
                } icon: {
                    Image("checklist", bundle: .module)
                }
            }
            .accessibilityIdentifier("settings-review")
            NavigationLink {
                ArchiveListView()
            } label: {
                Label {
                    Text("定着した課題", bundle: .module)
                } icon: {
                    Image("archive", bundle: .module)
                }
            }
            .accessibilityIdentifier("settings-archive")
            NavigationLink {
                ShelvedListView()
            } label: {
                Label {
                    Text("見送った課題", bundle: .module)
                } icon: {
                    Image("archive", bundle: .module)
                }
            }
            .accessibilityIdentifier("settings-shelved")
            NavigationLink {
                ExportView()
            } label: {
                Label {
                    Text("データの書き出し", bundle: .module)
                } icon: {
                    Image("ios_share", bundle: .module)
                }
            }
            .accessibilityIdentifier("settings-export")
            // 聞かれたときに答えが要る。ストアに出しているものと同じ URL(§1.2)
            if let privacyURL = URL(string: "https://tantan0327.github.io/bad-note/privacy.html") {
                Link(destination: privacyURL) {
                    Label {
                        Text("プライバシーポリシー", bundle: .module)
                    } icon: {
                        Image("info", bundle: .module)
                    }
                }
                .accessibilityIdentifier("settings-privacy")
            }
            #if DEBUG
            demoSection
            #endif
            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
               let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                Label {
                    Text(verbatim: "バージョン \(version) (\(buildNumber))")
                } icon: {
                    Image("info", bundle: .module)
                }
            }
        }
        .navigationTitle(Text("設定", bundle: .module))
        #if DEBUG
        .confirmationDialog(Text(verbatim: "デモデータを消しますか?"),
                            isPresented: $isShowingDemoWipeConfirmation,
                            titleVisibility: .visible) {
            Button(role: .destructive) {
                runDemo { try DemoData.wipe(db: $0) }
            } label: {
                Text(verbatim: "すべて消す")
            }
            // 「データをすべて消す」を部分一致で拾ってしまわないよう、
            // Maestro からは識別子で指す(iOS の照合は部分一致)
            .accessibilityIdentifier("settings-demo-wipe-confirm")
            Button(role: .cancel) {
            } label: {
                Text("やめる", bundle: .module)
            }
        }
        #endif
    }

    #if DEBUG
    /// ストアのスクリーンショット用(§1.4)。**開発ビルドにしか出ない。**
    ///
    /// 文言は `Text(verbatim:)` で書く —— `Scripts/sync-localizable.py` は
    /// `#if` を見ないので、`bundle: .module` にすると**開発用の文言が
    /// リリースの文字列カタログに残る**(画面には出ないが、入っているのは嘘)。
    ///
    /// 実データのままでは見映えのする画面が撮れないので、1 タップで入れて
    /// 1 タップで消す。消す側は**本物のデータも消える**ので確認を挟む。
    @ViewBuilder private var demoSection: some View {
        Section {
            Button {
                runDemo { try DemoData.seed(db: $0) }
            } label: {
                Text(verbatim: "デモデータを入れる")
            }
            .accessibilityIdentifier("settings-demo-seed")
            Button(role: .destructive) {
                isShowingDemoWipeConfirmation = true
            } label: {
                Text(verbatim: "データをすべて消す")
            }
            .accessibilityIdentifier("settings-demo-wipe")
            if let demoErrorText = demoErrorText {
                Text(demoErrorText)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        } header: {
            Text(verbatim: "開発用")
        } footer: {
            Text(verbatim: "スクリーンショットを撮るための仕掛けです。リリースビルドには入りません")
        }
    }

    private func runDemo(_ work: (SQLContext) throws -> Void) {
        do {
            try work(try AppDatabase.shared())
            demoErrorText = nil
        } catch {
            demoErrorText = "失敗しました: \(error)"
        }
    }
    #endif
}
