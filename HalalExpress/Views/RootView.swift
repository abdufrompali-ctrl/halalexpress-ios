import SwiftUI

enum AppTab: Hashable { case home, order, rewards, settings }

struct RootView: View {
    @State private var tab: AppTab = .home

    init() {
        // Paper tab bar: warm off-white, red for the selected tab, a hairline top edge.
        let a = UITabBarAppearance()
        a.configureWithOpaqueBackground()
        a.backgroundColor = UIColor(Paper.bg)
        a.shadowColor = UIColor(Paper.line)
        let sel = UIColor(Paper.red)
        let norm = UIColor(Paper.inkFaint)
        for s in [a.stackedLayoutAppearance, a.inlineLayoutAppearance, a.compactInlineLayoutAppearance] {
            s.selected.iconColor = sel
            s.selected.titleTextAttributes = [.foregroundColor: sel]
            s.normal.iconColor = norm
            s.normal.titleTextAttributes = [.foregroundColor: norm]
        }
        UITabBar.appearance().standardAppearance = a
        UITabBar.appearance().scrollEdgeAppearance = a
    }

    var body: some View {
        TabView(selection: $tab) {
            HomeView(goOrder: { tab = .order })
                .tabItem { Label("Home", systemImage: "house") }
                .tag(AppTab.home)

            OrderView()
                .tabItem { Label("Menu", systemImage: "list.bullet") }
                .tag(AppTab.order)

            RewardsView()
                .tabItem { Label("Updates", systemImage: "bell") }
                .tag(AppTab.rewards)

            SettingsView()
                .tabItem { Label("Account", systemImage: "person") }
                .tag(AppTab.settings)
        }
        .tint(Paper.red)
    }
}
