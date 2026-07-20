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
