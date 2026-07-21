import SwiftUI

enum AppTab: Hashable { case home, order, rewards, settings }

struct RootView: View {
    @State private var tab: AppTab = .home

    init() {
        // Warm, on-brand tab bar (ember selected, warm charcoal background).
        let a = UITabBarAppearance()
        a.configureWithOpaqueBackground()
        a.backgroundColor = UIColor(Brand.warmBg2)
        a.shadowColor = UIColor.white.withAlphaComponent(0.06)
        let sel = UIColor(Brand.emberSoft)
        let norm = UIColor.white.withAlphaComponent(0.42)
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
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(AppTab.home)

            OrderView()
                .tabItem { Label("Order", systemImage: "bag.fill") }
                .tag(AppTab.order)

            RewardsView()
                .tabItem { Label("Rewards", systemImage: "star.fill") }
                .tag(AppTab.rewards)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(AppTab.settings)
        }
        .tint(Brand.ember)
    }
}
