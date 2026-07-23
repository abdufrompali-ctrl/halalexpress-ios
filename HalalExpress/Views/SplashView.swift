import SwiftUI

/// Cold-launch wordmark: the HALAL EXPRESS board name inked on paper with a red
/// rule drawn beneath it. Shown once per launch. Honours Reduce Motion.
struct SplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appear = false

    var body: some View {
        ZStack {
            Paper.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Text("HALAL")
                    .font(.board(88))
                    .foregroundStyle(Paper.ink)
                Text("EXPRESS")
                    .font(.board(88))
                    .foregroundStyle(Paper.red)

                Rectangle()
                    .fill(Paper.red)
                    .frame(width: appear || reduceMotion ? 148 : 0, height: 5)
                    .padding(.top, 14)

                Text("HALAL FOOD TRUCK · WILMINGTON, NC")
                    .font(.system(.footnote, design: .default).weight(.semibold))
                    .tracking(1.5)
                    .foregroundStyle(Paper.inkSoft)
                    .padding(.top, 16)
                    .opacity(appear || reduceMotion ? 1 : 0)
            }
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            guard !reduceMotion else { appear = true; return }
            withAnimation(.easeOut(duration: 0.5)) { appear = true }
        }
    }
}
