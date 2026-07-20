import SwiftUI

enum AppTab: Hashable {
    case home, menu, cart, rewards
}

struct RootView: View {
    @EnvironmentObject private var cart: CartStore
    @State private var tab: AppTab = .home

    var body: some View {
        TabView(selection: $tab) {
            HomeView(switchTab: { tab = $0 })
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(AppTab.home)

            MenuView()
                .tabItem { Label("Menu", systemImage: "fork.knife") }
                .tag(AppTab.menu)

            CartView()
                .tabItem { Label("Cart", systemImage: "cart") }
                .badge(cart.itemCount > 0 ? "\(cart.itemCount)" : nil)
                .tag(AppTab.cart)

            RewardsView()
                .tabItem { Label("Rewards", systemImage: "star") }
                .tag(AppTab.rewards)
        }
        .animation(.snappy, value: cart.itemCount)
    }
}
