import SwiftUI

@main
struct HalalExpressApp: App {
    @StateObject private var cart = CartStore()
    @StateObject private var orders = OrderHistoryStore()
    @AppStorage("onboardingComplete") private var onboardingComplete = false
    @State private var showSplash = true
    @State private var showOnboarding = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .environmentObject(cart)
                    .environmentObject(orders)
                    .tint(Paper.red)

                if showSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .preferredColorScheme(.light)   // the design commits to paper — light only
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingView(onDone: { showOnboarding = false })
            }
            .task { await openingSequence() }   // once per launch, not on every foreground
            .task { APIClient.shared.prefetchConfig() }   // warm payment config before first checkout
        }
    }

    /// Show the wordmark briefly on cold launch, then reveal the app. First run
    /// only, offer the (skippable) text-list sign-up. Runs once — no stacked timers,
    /// no replay when returning from the background.
    private func openingSequence() async {
        try? await Task.sleep(for: .seconds(1.1))
        withAnimation(.easeOut(duration: 0.4)) { showSplash = false }
        if !onboardingComplete { showOnboarding = true }
    }
}
