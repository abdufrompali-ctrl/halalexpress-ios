import SwiftUI

@main
struct HalalExpressApp: App {
    @StateObject private var cart = CartStore()
    @StateObject private var orders = OrderHistoryStore()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("onboardingComplete") private var onboardingComplete = false
    @State private var showSplash = true
    @State private var showOnboarding = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .environmentObject(cart)
                    .environmentObject(orders)
                    .tint(Brand.red)

                if showSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingView(onDone: { showOnboarding = false })
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
            // First open only: greet with the Rewards sign-up (skippable).
            if !onboardingComplete {
                showOnboarding = true
            }
        }
    }
}
