import SwiftUI

@main
struct HalalExpressApp: App {
    @StateObject private var cart = CartStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(cart)
                .tint(Brand.red)
        }
    }
}
