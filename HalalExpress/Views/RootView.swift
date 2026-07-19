import SwiftUI

struct RootView: View {
    @EnvironmentObject private var cart: CartStore

    var body: some View {
        TabView {
            MenuView()
                .tabItem { Label("Menu", systemImage: "fork.knife") }

            CartView()
                .tabItem { Label("Cart", systemImage: "cart") }
                .badge(cart.itemCount > 0 ? "\(cart.itemCount)" : nil)

            RewardsView()
                .tabItem { Label("Rewards", systemImage: "star") }
        }
    }
}
