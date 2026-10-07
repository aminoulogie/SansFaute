import SwiftUI

@main
struct SansFauteApp: App {
    @StateObject private var content = ContentStore()
    @StateObject private var progress = ProgressStore()
    @StateObject private var speaker = Speaker.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(content)
                .environmentObject(progress)
                .environmentObject(speaker)
                .tint(Theme.ink)
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Aujourd'hui", systemImage: "sun.max.fill") }
            ListeningHomeView()
                .tabItem { Label("Écoute", systemImage: "headphones") }
            GrammarHomeView()
                .tabItem { Label("Grammaire", systemImage: "textformat") }
            VocabHomeView()
                .tabItem { Label("Mots", systemImage: "rectangle.stack.fill") }
            TestsHomeView()
                .tabItem { Label("Tests", systemImage: "chart.line.uptrend.xyaxis") }
        }
        .toolbarBackground(Theme.card, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
