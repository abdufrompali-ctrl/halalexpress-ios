import SwiftUI

/// Abstract, modern splash: the HALAL EXPRESS wordmark rises and reveals over
/// the ember backdrop, with a growing accent rule. Shown on every app open.
struct SplashView: View {
    @State private var appear = false

    /// Ember-tinted vertical fill for the wordmark (white → warm → ember).
    private let emberText = LinearGradient(
        colors: [.white, Brand.emberSoft, Brand.ember],
        startPoint: .top, endPoint: .bottom)

    var body: some View {
        ZStack {
            BrandBackground()

            VStack(alignment: .leading, spacing: 0) {
                Text("EST. HALAL · MADE FRESH")
                    .font(.caption2.weight(.semibold))
                    .kerning(3)
                    .foregroundStyle(Brand.emberSoft)
                    .opacity(appear ? 1 : 0)
                    .animation(.easeOut(duration: 0.6), value: appear)
                    .padding(.bottom, 14)

                wordLine("HALAL",   delay: 0.08)
                wordLine("EXPRESS", delay: 0.18)

                Rectangle()
                    .fill(LinearGradient.brand)
                    .frame(width: appear ? 132 : 0, height: 4)
                    .clipShape(Capsule())
                    .padding(.top, 18)
                    .animation(.easeOut(duration: 0.7).delay(0.34), value: appear)

                Text("Authentic halal, made fresh on the truck.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 10)
                    .animation(.easeOut(duration: 0.6).delay(0.46), value: appear)
                    .padding(.top, 16)
            }
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear { appear = true }
    }

    /// One line of the wordmark that clips-and-rises into view.
    private func wordLine(_ text: String, delay: Double) -> some View {
        Text(text)
            .font(.display(80))
            .foregroundStyle(emberText)
            .kerning(1)
            .offset(y: appear ? 0 : 44)
            .opacity(appear ? 1 : 0)
            .mask {
                Rectangle()
                    .scaleEffect(x: 1, y: appear ? 1 : 0.01, anchor: .bottom)
            }
            .animation(.spring(response: 0.75, dampingFraction: 0.78).delay(delay), value: appear)
    }
}
