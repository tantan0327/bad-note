import SwiftUI

enum ContentTab: String, Hashable {
    case home, issues, competitions
}

/// タブは「往復するもの」だけ。3 つに絞っている。
///
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
            NavigationLink {
                ArchiveListView()
            } label: {
                Text("定着した課題", bundle: .module)
            }
            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
               let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                Text(verbatim: "バージョン \(version) (\(buildNumber))")
            }
        }
        .navigationTitle(Text("設定", bundle: .module))
    }
}
