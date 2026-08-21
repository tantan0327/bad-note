import SwiftUI

enum ContentTab: String, Hashable {
    case welcome, home, settings
}

struct ContentView: View {
    @AppStorage("tab") var tab = ContentTab.welcome
    @AppStorage("name") var welcomeName = "Skipper"
    @AppStorage("appearance") var appearance = ""
    @State var viewModel = ViewModel()

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack {
                WelcomeView(welcomeName: $welcomeName)
            }
            .tabItem {
                Label {
                    Text("ようこそ", bundle: .module, comment: "welcome tab label")
                } icon: {
                    Image("favorite", bundle: .module)
                }
            }
            .tag(ContentTab.welcome)

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
                SettingsView(appearance: $appearance, welcomeName: $welcomeName)
                    .navigationTitle("Settings")
            }
            .tabItem {
                Label {
                    Text("設定", bundle: .module, comment: "settings tab label")
                } icon: {
                    Image("settings", bundle: .module)
                }
            }
            .tag(ContentTab.settings)
        }
        .environment(viewModel)
        .preferredColorScheme(appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
    }
}

struct WelcomeView : View {
    @State var heartBeating = false
    @Binding var welcomeName: String

    var body: some View {
        VStack(spacing: 0) {
            Text("Hello [\(welcomeName)](https://skip.dev)!")
                .padding()
            Image("favorite", bundle: .module)
                .foregroundStyle(.red)
                .scaleEffect(heartBeating ? 1.5 : 1.0)
                .task {
                    withAnimation(.easeInOut(duration: 1).repeatForever()) {
                        heartBeating = true
                    }
                }
        }
        .font(.largeTitle)
    }
}

struct SettingsView : View {
    @Binding var appearance: String
    @Binding var welcomeName: String

    var body: some View {
        Form {
            TextField("Name", text: $welcomeName)
            Picker("Appearance", selection: $appearance) {
                Text("System").tag("")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
               let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                Text("Version \(version) (\(buildNumber))")
            }
            HStack {
                PlatformHeartView()
                Text("Powered by [Skip](https://skip.dev)")
            }
        }
    }
}

/// A view that shows a blue heart on iOS and a green heart on Android.
struct PlatformHeartView : View {
    var body: some View {
       #if SKIP
       ComposeView { ctx in // Mix in Compose code!
           androidx.compose.material3.Text("💚", modifier: ctx.modifier)
       }
       #else
       Text(verbatim: "💙")
       #endif
    }
}
