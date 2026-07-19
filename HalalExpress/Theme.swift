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
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}
