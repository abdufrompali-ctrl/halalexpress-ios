import SwiftUI

/// Branded splash shown on every app open (cold launch + return from background).
struct SplashView: View {
    @State private var appear = false

    var body: some View {
        ZStack {
            LinearGradient.brand.ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "truck.box.fill")
                    .font(.system(size: 84))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                    .scaleEffect(appear ? 1 : 0.55)
                    .opacity(appear ? 1 : 0)

                VStack(spacing: 6) {
                    Text("HALAL EXPRESS")
                        .font(.largeTitle.weight(.black))
                        .foregroundStyle(.white)
                        .kerning(1.5)
                    Text("Authentic halal, made fresh")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                }
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 12)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                appear = true
            }
        }
    }
}
