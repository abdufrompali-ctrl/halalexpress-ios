import SwiftUI

// Brand palette — mirrors the website's CSS variables (src/index.css):
// --red #cc1111, --red-deep #8f0a0a, --ember #ff3b1d, --ember-soft #ff6a4d,
// --yellow #e2aa53, truck ink #0e0e0e.
enum Brand {
    static let red       = Color(hex: 0xCC1111)
    static let redDeep   = Color(hex: 0x8F0A0A)
    static let ember     = Color(hex: 0xFF3B1D)
    static let emberSoft = Color(hex: 0xFF6A4D)
    static let gold      = Color(hex: 0xE2AA53)
    static let ink       = Color(hex: 0x0E0E0E)
    static let darkBody  = Color(hex: 0x111010)
    static let darkCard  = Color(hex: 0x1C1A1A)
}

struct DiagonalSlash: Shape {
    var rise: CGFloat = 56
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: rect.maxX, y: 0))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - rise))
        p.addLine(to: CGPoint(x: 0, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

extension LinearGradient {
    /// The signature ember→red→deep diagonal used across the brand.
    static let brand = LinearGradient(
        colors: [Brand.ember, Brand.red, Brand.redDeep],
        startPoint: .topLeading, endPoint: .bottomTrailing)
}

extension Font {
    /// Bundled condensed display face (Bebas Neue) for wordmarks & big titles.
    /// Falls back to the system font automatically if the file fails to register.
    static func display(_ size: CGFloat) -> Font { .custom("BebasNeue-Regular", size: size) }
}

extension Brand {
    /// SF Symbol per menu category, for a little visual texture on headers.
    static func icon(for category: String) -> String {
        switch category.uppercased() {
        case "PLATES": return "fork.knife"
        case "WRAPS":  return "takeoutbag.and.cup.and.straw.fill"
        case "LOADED": return "flame.fill"
        case "SIDES":  return "carrot.fill"
        case "EXTRAS": return "plus.circle.fill"
        default:       return "circle.grid.2x2.fill"
        }
    }
}

// MARK: - Reusable branded components

/// Full-width primary action: brand gradient, subtle press feedback + shadow.
struct BrandButtonStyle: ButtonStyle {
    var enabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background {
                if enabled {
                    LinearGradient.brand
                } else {
                    Color.gray.opacity(0.4)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: enabled ? Brand.red.opacity(0.35) : .clear,
                    radius: 10, y: 5)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Item photo with a branded gradient+icon placeholder. Shows the real Square
/// photo once `item.imageURL` exists; until then the placeholder looks intentional.
/// Caller sets the frame.
struct MenuItemImage: View {
    let item: CatalogItem
    var corner: CGFloat = 14
    var iconSize: CGFloat = 28

    var body: some View {
        ZStack {
            LinearGradient.brand
            if let url = item.imageURL {
                AsyncImage(url: url) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    icon
                }
            } else {
                icon
            }
        }
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: corner))
    }

    private var icon: some View {
        Image(systemName: Brand.icon(for: item.category))
            .font(.system(size: iconSize))
            .foregroundStyle(.white.opacity(0.9))
    }
}

/// Format a server slot (JS toISOString(), includes fractional seconds) as "6:45 PM".
func slotTimeLabel(_ iso: String) -> String {
    let withFrac = ISO8601DateFormatter()
    withFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    guard let date = withFrac.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) else {
        return iso
    }
    return date.formatted(date: .omitted, time: .shortened)
}

/// Parse a server slot ISO string into a Date (fractional-seconds tolerant).
func slotDate(_ iso: String) -> Date? {
    let withFrac = ISO8601DateFormatter()
    withFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return withFrac.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
}

// MARK: - App background ("wallpaper")

/// A faint engineering grid used as subtle background texture.
struct GridPattern: Shape {
    var spacing: CGFloat = 44
    func path(in rect: CGRect) -> Path {
        var p = Path()
        var x = rect.minX
        while x <= rect.maxX {
            p.move(to: CGPoint(x: x, y: rect.minY))
            p.addLine(to: CGPoint(x: x, y: rect.maxY))
            x += spacing
        }
        var y = rect.minY
        while y <= rect.maxY {
            p.move(to: CGPoint(x: rect.minX, y: y))
            p.addLine(to: CGPoint(x: rect.maxX, y: y))
            y += spacing
        }
        return p
    }
}

/// Deterministic film-grain speckle drawn once with Canvas (no image asset, no
/// per-frame cost). `.overlay` blend lifts the flat black without banding.
struct GrainOverlay: View {
    var intensity: Double = 0.05
    var body: some View {
        Canvas { ctx, size in
            var seed: UInt64 = 0x9E3779B97F4A7C15
            func rnd() -> Double {                         // xorshift PRNG, fixed seed → stable grain
                seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
                return Double(seed % 100_000) / 100_000.0
            }
            let count = Int(size.width * size.height / 480)
            for _ in 0..<count {
                let rect = CGRect(x: rnd() * size.width, y: rnd() * size.height,
                                  width: 1.1, height: 1.1)
                ctx.fill(Path(rect), with: .color(.white.opacity(rnd() * intensity)))
            }
        }
        .blendMode(.overlay)
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

/// Abstract black / crimson / ember backdrop that replaces flat fills app-wide.
/// Mirrors the website hero: near-black base, layered radial ember glows that
/// slowly breathe & drift, a faint edge-fading grid, and fine film grain.
struct BrandBackground: View {
    /// Pass `false` behind heavy scrolling lists to skip the animation.
    var animated: Bool = true
    @State private var t = false

    var body: some View {
        ZStack {
            Color(hex: 0x070606)                                    // near-black base

            // Top crimson bloom
            RadialGradient(colors: [Brand.red.opacity(0.20),
                                    Brand.redDeep.opacity(0.06), .clear],
                           center: UnitPoint(x: 0.5, y: -0.05),
                           startRadius: 0, endRadius: 540)

            // Hot ember orb, lower-trailing — breathes & drifts (blurred circle
            // so offset/scale/opacity tween smoothly; a RadialGradient would snap)
            Circle()
                .fill(Brand.ember)
                .frame(width: 460, height: 460)
                .blur(radius: 100)
                .opacity(t ? 0.32 : 0.20)
                .scaleEffect(t ? 1.10 : 0.95)
                .offset(x: t ? 150 : 190, y: t ? 300 : 360)

            // Soft warm orb, mid-leading — counter-drifts
            Circle()
                .fill(Brand.emberSoft)
                .frame(width: 340, height: 340)
                .blur(radius: 90)
                .opacity(t ? 0.16 : 0.10)
                .scaleEffect(t ? 1.05 : 0.92)
                .offset(x: t ? -150 : -120, y: t ? -20 : 40)

            // Faint grid, masked to fade at the edges
            GridPattern(spacing: 44)
                .stroke(Color.white.opacity(0.05), lineWidth: 0.6)
                .mask {
                    RadialGradient(colors: [.white, .clear],
                                   center: UnitPoint(x: 0.5, y: 0.34),
                                   startRadius: 0, endRadius: 480)
                }

            GrainOverlay()
        }
        .ignoresSafeArea()
        .onAppear {
            guard animated else { return }
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
                t = true
            }
        }
    }
}

/// Frosted "glass" surface: translucent material + a faint white hairline, so
/// cards lift off the ember backdrop instead of reading as flat blocks.
struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 18
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Color.white.opacity(0.09), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
    }
}

/// Staggered fade-up used to give screens a little life on appear.
struct AppearFadeUp: ViewModifier {
    var delay: Double = 0
    @State private var shown = false
    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 16)
            .onAppear {
                withAnimation(.easeOut(duration: 0.55).delay(delay)) { shown = true }
            }
    }
}

extension View {
    /// Frosted glass card surface (see `GlassCard`).
    func glassCard(cornerRadius: CGFloat = 18) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }
    /// Fade + rise in on appear, optionally staggered by `delay`.
    func appearFadeUp(delay: Double = 0) -> some View {
        modifier(AppearFadeUp(delay: delay))
    }
}

/// Rounded price chip used on menu rows.
struct PricePill: View {
    let cents: Int
    var body: some View {
        Text(dollars(cents))
            .font(.subheadline.weight(.bold).monospacedDigit())
            .foregroundStyle(Brand.red)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Brand.red.opacity(0.10), in: Capsule())
    }
}
