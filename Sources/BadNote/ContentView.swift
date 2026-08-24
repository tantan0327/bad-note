import SwiftUI

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
            }
            .tag(ContentTab.competitions)
        }
    }
}

/// 設定(§4.2 の閾値、§8 の通知、アーカイブ閲覧の置き場)。
///
/// 日常操作ではないので、ホームのツールバーから開く。
struct SettingsView: View {
    var body: some View {
        Form {
            // 上から「設定するもの」→「眺めるもの」の順(2.6)
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
                ExportView()
            } label: {
                Label {
                    Text("データの書き出し", bundle: .module)
                } icon: {
                    Image("ios_share", bundle: .module)
                }
            }
            .accessibilityIdentifier("settings-export")
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
    }
}
