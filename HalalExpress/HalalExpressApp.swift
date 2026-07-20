import SwiftUI

@main
struct HalalExpressApp: App {
    @StateObject private var cart = CartStore()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .environmentObject(cart)
                    .tint(Brand.red)

                if showSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .onAppear(perform: playSplash)
            .onChange(of: scenePhase) { old, new in
                // Re-play the splash when the app is reopened from the background.
                if new == .active && old == .background {
                    showSplash = true
                    playSplash()
                }
            }
        }
    }

    private func playSplash() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
            withAnimation(.easeOut(duration: 0.45)) {
                showSplash = false
            }
        }
    }
}
