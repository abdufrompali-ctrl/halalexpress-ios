import SwiftUI

struct RootView: View {
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
        TabView {
            OrderView()
                .tabItem { Label("Order", systemImage: "bag.fill") }

            LocateView()
                .tabItem { Label("Locate", systemImage: "mappin.and.ellipse") }

            MenuView()
                .tabItem { Label("Menu", systemImage: "fork.knife") }

            RewardsView()
                .tabItem { Label("Rewards", systemImage: "star.fill") }
        }
        .tint(Brand.ember)
    }
}
