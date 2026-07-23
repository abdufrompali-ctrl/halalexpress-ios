import SwiftUI

// MARK: - Palette — "butcher paper & board"
//
// Ink on warm paper, one signage red, prices set in tabular figures like a
// receipt. No gradients, no glass, no glow, no floating orbs. The screen is the
// paper the truck prints on; rules and boxes do the work cards and shadows used to.

enum Paper {
    static let bg       = Color(hex: 0xF4EFE7)   // main paper ground
    static let panel    = Color(hex: 0xEBE1D1)   // inset panel / secondary block
    static let panelDim = Color(hex: 0xE4D9C6)   // pressed / disabled fill
    static let ink      = Color(hex: 0x17130F)   // primary text — warm near-black
    static let inkSoft  = Color(hex: 0x5B5249)   // secondary text
    static let inkFaint = Color(hex: 0x93887A)   // tertiary / hints
    static let line     = Color(hex: 0xD5C9B6)   // hairline rules & borders
    static let lineBold = Color(hex: 0x17130F)   // heavy rule (board headers)
    static let red      = Color(hex: 0xC81E1E)   // the one accent
    static let redDeep  = Color(hex: 0x9E1214)   // pressed red
    static let open     = Color(hex: 0x2F7D31)   // "open" status — the only other hue
    static let radius: CGFloat = 0               // menu-board square corners

    // The black menu-board — a chalkboard mounted on the paper. Hero headers sit on
    // it in "chalk" cream with the one red accent; content stays on the paper below.
    static let board        = Color(hex: 0x1C1714)   // warm near-black board surface
    static let boardInk     = Color(hex: 0xF4EFE7)   // chalk text on the board
    static let boardInkSoft = Color(hex: 0xA89C8A)   // muted chalk (subtitles)
    static let hatch        = Color(hex: 0xCBBDA5)   // faint diagonal lines on paper
    static let boardHatch   = Color(hex: 0xF4EFE7)   // chalk hatch on the board (low opacity)
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

// MARK: - Type
//
// One display face used sparingly (Bebas Neue — the hand-lettered board), system
// text for everything readable, tabular mono for money. Sizes are anchored to
// Dynamic Type text styles with `relativeTo:` so type actually scales.

extension Font {
    /// Condensed board/wordmark face. Reach for it only on screen titles, category
    /// headers and the wordmark — never body copy.
    static func board(_ size: CGFloat, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
        .custom("BebasNeue-Regular", size: size, relativeTo: style)
    }

    /// Tabular figures for prices & totals — receipt authenticity, and they line up
    /// in a column. Proportional letters, monospaced digits.
    static func price(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold).monospacedDigit()
    }
}

// MARK: - Rules & leaders
//
// The vocabulary that replaces cards: a hairline rule, a heavy rule, and the
// dotted leader that runs a menu row's name out to its price.

struct Rule: View {
    var color: Color = Paper.line
    var height: CGFloat = 1
    var body: some View { Rectangle().fill(color).frame(height: height) }
}

/// Row of evenly-spaced dots — the "………" between a dish and its price on a
/// printed menu. Drawn once, cheaply, and it tiles to any width.
struct DottedLeader: View {
    var color: Color = Paper.inkFaint
    var body: some View {
        Line()
            .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [1.5, 4]))
            .foregroundStyle(color)
            .frame(height: 1)
            .padding(.bottom, 3)
    }
    private struct Line: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path(); p.move(to: CGPoint(x: 0, y: r.midY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.midY)); return p
        }
    }
}

// MARK: - Surfaces
//
// A boxed section: paper panel behind a hairline border. This is the app's one
// card treatment — square, flat, no shadow. It replaced an animated gradient-orb
// background whose 460pt circle used to inflate every screen past the viewport
// and clip the edges; the screen is now simply the paper (`Paper.bg`).

struct PaperBox: ViewModifier {
    var fill: Color = Paper.panel
    var border: Color = Paper.line
    func body(content: Content) -> some View {
        content
            .background(fill)
            .overlay(Rectangle().stroke(border, lineWidth: 1))
    }
}

extension View {
    /// Boxed hairline panel on paper — the only card surface in the app.
    func paperBox(fill: Color = Paper.panel, border: Color = Paper.line) -> some View {
        modifier(PaperBox(fill: fill, border: border))
    }
}

// MARK: - Angular hatch
//
// Evenly-spaced 45° hairlines — the "printed on kraft paper" field the whole app
// floats on. Drawn once in a Canvas so it stays crisp and cheap at any size, and
// never intercepts touches. Faint tan on paper; low-opacity chalk on the board.

struct DiagonalHatch: View {
    var color: Color = Paper.hatch
    var spacing: CGFloat = 15
    var lineWidth: CGFloat = 1
    /// Down-right (`true`) or up-right slope, so board and paper can lean opposite ways.
    var descending: Bool = true

    var body: some View {
        Canvas { ctx, size in
            var path = Path()
            var x = -size.height
            while x < size.width {
                if descending {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x + size.height, y: size.height))
                } else {
                    path.move(to: CGPoint(x: x + size.height, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                }
                x += spacing
            }
            ctx.stroke(path, with: .color(color), lineWidth: lineWidth)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Board hero header
//
// The black chalkboard header that tops a screen: an optional red eyebrow, a big
// board-face title, and room for a trailing mark (a status stamp, say). A chalk
// hatch runs behind it and a red baseline underlines it like a signwriter's rule.

struct BoardHeader<Trailing: View>: View {
    var eyebrow: String?
    var title: String
    /// Bottom edge: a thin solid red rule (default) or a bold red diagonal-stripe band.
    var stripes: Bool = false
    /// Chalk hatch strength inside the board (0 = flat black).
    var boardHatch: Double = 0.05
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                if let eyebrow {
                    Text(eyebrow)
                        .font(.system(.caption, design: .default).weight(.heavy)).tracking(1.5)
                        .foregroundStyle(Paper.red)
                }
                Text(title).font(.board(50)).foregroundStyle(Paper.boardInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 20).padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                Paper.board
                if boardHatch > 0 {
                    DiagonalHatch(color: Paper.boardHatch.opacity(boardHatch), spacing: 16, descending: false)
                }
            }
        }
        .overlay(alignment: .bottom) {
            if stripes {
                DiagonalHatch(color: Paper.red, spacing: 11, lineWidth: 5, descending: true)
                    .frame(height: 16).clipped().background(Paper.board)
            } else {
                Rectangle().fill(Paper.red).frame(height: 3)
            }
        }
    }
}

extension BoardHeader where Trailing == EmptyView {
    init(eyebrow: String? = nil, title: String, stripes: Bool = false, boardHatch: Double = 0.05) {
        self.init(eyebrow: eyebrow, title: title, stripes: stripes, boardHatch: boardHatch) { EmptyView() }
    }
}

/// The app's page background: warm paper under a faint, wide diagonal "kraft"
/// field — identical on every screen. Panels drawn on top (`paperBox`) sit opaque
/// over the field, so the lines only whisper through in the gutters. Use as a
/// bottom ZStack layer, or via `.paperGround()` as a background modifier.
struct PaperGroundLayer: View {
    var body: some View {
        ZStack {
            Paper.bg
            DiagonalHatch(color: Paper.hatch.opacity(0.28), spacing: 40, lineWidth: 1)
        }
        .ignoresSafeArea()
    }
}

extension View {
    func paperGround() -> some View {
        background { PaperGroundLayer() }
    }
}

// MARK: - Status stamp
//
// The green/red "OPEN"/"CLOSED" mark, set like an inked rubber stamp.

struct StatusStamp: View {
    let open: Bool
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(open ? Paper.open : Paper.red).frame(width: 7, height: 7)
            Text(open ? "OPEN" : "CLOSED")
                .font(.system(.caption, design: .default).weight(.heavy))
                .tracking(1)
                .foregroundStyle(open ? Paper.open : Paper.red)
        }
    }
}

// MARK: - Buttons
//
// The primary action is a solid red signage block. No gradient, no glow shadow —
// just ink-firm colour and a small press state.

struct SignButtonStyle: ButtonStyle {
    var enabled: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return configuration.label
            .font(.system(.headline, design: .default).weight(.semibold))
            .foregroundStyle(enabled ? Color.white : Paper.inkFaint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(enabled ? (configuration.isPressed ? Paper.redDeep : Paper.red)
                                : Paper.panelDim, in: shape)
            .overlay(shape.stroke(enabled ? .clear : Paper.line, lineWidth: 1))
            .contentShape(shape)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}

/// Light press feedback for buttons that supply their own background.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
    }
}

// MARK: - Item image
//
// Real Square photos now exist, so show them honestly at size — no red gradient
// behind, no SF Symbol pretending to be food. When a photo is missing, fall back
// to a plain typographic tile (the dish's initial on paper) rather than faking one.

struct MenuItemImage: View {
    let item: CatalogItem

    var body: some View {
        Rectangle()
            .fill(Paper.panel)
            .overlay {
                if let url = item.imageURL {
                    AsyncImage(url: url) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        fallback
                    }
                } else {
                    fallback
                }
            }
            .clipped()
            .overlay(Rectangle().stroke(Paper.line, lineWidth: 1))
            .accessibilityLabel(Text(item.name))
    }

    private var fallback: some View {
        Text(item.name.prefix(1).uppercased())
            .font(.board(40))
            .foregroundStyle(Paper.inkFaint)
    }
}

// MARK: - Slot time helpers (unchanged)

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
