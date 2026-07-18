import SwiftUI
import UIKit

struct ThemePalette: Equatable {
    let accent: Color
    let secondary: Color
    let canvas: Color
    let surface: Color
    let ink: Color
    let inkMuted: Color
    var isGlass: Bool = false
    var glow: Color? = nil
}

enum AppTheme: String, CaseIterable, Identifiable {
    case filmNegative = "film_negative"
    case daylight
    case bright
    case cyber
    case darkroom
    case fjord
    case lavender

    static let storageKey = "appTheme"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .filmNegative: String(localized: "Negatif", bundle: .appLanguage)
        case .daylight:     String(localized: "Aydınlık", bundle: .appLanguage)
        case .bright:       String(localized: "Canlı", bundle: .appLanguage)
        case .cyber:        String(localized: "Grafit", bundle: .appLanguage)
        case .darkroom:     String(localized: "Karanlık Oda", bundle: .appLanguage)
        case .fjord:        String(localized: "Fiyort", bundle: .appLanguage)
        case .lavender:     String(localized: "Lavanta", bundle: .appLanguage)
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .daylight: .light
        case .darkroom, .cyber: .dark
        default: nil
        }
    }

    var palette: ThemePalette {
        switch self {
        case .filmNegative:
            ThemePalette(
                accent: Color(light: "2E8B57", dark: "5FD98A"),
                secondary: Color(light: "1F6B6E", dark: "4FADAF"),
                canvas: Color(light: "F3F0EA", dark: "16140F"),
                surface: Color(light: "FFFFFF", dark: "211E19"),
                ink: Color(light: "241F1B", dark: "F2EEE7"),
                inkMuted: Color(light: "6E675E", dark: "B3ABA0")
            )
        case .daylight:
            ThemePalette(
                accent: Color(light: "007AFF", dark: "007AFF"),
                secondary: Color(light: "30B0C7", dark: "30B0C7"),
                canvas: Color(light: "F6F7F9", dark: "F6F7F9"),
                surface: Color(light: "FFFFFF", dark: "FFFFFF"),
                ink: Color(light: "0B0C0E", dark: "0B0C0E"),
                inkMuted: Color(light: "83898F", dark: "83898F")
            )
        case .bright:
            ThemePalette(
                accent: Color(light: "4F46E5", dark: "8B85F4"),
                secondary: Color(light: "F97066", dark: "FDA29B"),
                canvas: Color(light: "FBFBFE", dark: "0F1017"),
                surface: Color(light: "FFFFFF", dark: "1A1B23"),
                ink: Color(light: "111322", dark: "F0F1F7"),
                inkMuted: Color(light: "667085", dark: "9CA1B0")
            )
        case .cyber:
            ThemePalette(
                accent: Color(light: "3B6EA5", dark: "6FA8DC"),
                secondary: Color(light: "5A6472", dark: "9AA4B2"),
                canvas: Color(light: "0F1115", dark: "0F1115"),
                surface: Color(light: "1A1D23", dark: "1A1D23"),
                ink: Color(light: "F2F3F5", dark: "F2F3F5"),
                inkMuted: Color(light: "9AA0A8", dark: "9AA0A8")
            )
        case .darkroom:
            ThemePalette(
                accent: Color(light: "E3A23B", dark: "E3A23B"),
                secondary: Color(light: "C4574A", dark: "C4574A"),
                canvas: Color(light: "121110", dark: "121110"),
                surface: Color(light: "1F1C18", dark: "1F1C18"),
                ink: Color(light: "F4EDE1", dark: "F4EDE1"),
                inkMuted: Color(light: "9A9187", dark: "9A9187")
            )
        case .fjord:
            ThemePalette(
                accent: Color(light: "3E5C95", dark: "8FB0EA"),
                secondary: Color(light: "2E7D6B", dark: "6FBFAB"),
                canvas: Color(light: "F2F4F7", dark: "10141B"),
                surface: Color(light: "FFFFFF", dark: "1B2230"),
                ink: Color(light: "1C2430", dark: "E9EEF6"),
                inkMuted: Color(light: "5F6B7A", dark: "97A3B4")
            )
        case .lavender:
            ThemePalette(
                accent: Color(light: "7C6BB8", dark: "AFA1E8"),
                secondary: Color(light: "B06A8C", dark: "E0A2C0"),
                canvas: Color(light: "F5F3F9", dark: "161320"),
                surface: Color(light: "FFFFFF", dark: "221E30"),
                ink: Color(light: "27223A", dark: "EFECF7"),
                inkMuted: Color(light: "6E6885", dark: "ABA4C2")
            )
        }
    }
}

extension EnvironmentValues {
    @Entry var theme: ThemePalette = AppTheme.filmNegative.palette
}

enum Theme {

    static let brand = Color(light: "2E8B57", dark: "5FD98A")

    static func accent(for category: ProjectCategory) -> Color {
        switch category {
        case .selfPortrait: Color(light: "2E8B57", dark: "5FD98A")
        case .person:       Color(light: "5E5CE6", dark: "9D9BF5")
        case .child:        Color(light: "B8637A", dark: "E79CAE")
        case .plant:        Color(light: "4C7A52", dark: "8FC79A")
        case .hairAndBeard: Color(light: "8A6A4E", dark: "C9A97D")
        case .pet:          Color(light: "5B7FBF", dark: "94B4F2")
        case .fitness:      Color(light: "B0722E", dark: "E0A468")
        case .pregnancy:    Color(light: "9A5BA6", dark: "C99BD6")
        case .baby:         Color(light: "3E8E9E", dark: "7FC3D1")
        case .outfit:       Color(light: "B0568A", dark: "D98BB8")
        case .coupleMode:   Color(light: "C2566B", dark: "F191A6")
        case .other:        Color(light: "6E675E", dark: "B3ABA0")
        }
    }

    static func icon(for category: ProjectCategory) -> String {
        switch category {
        case .selfPortrait: "person.crop.circle"
        case .person:       "person.fill"
        case .child:        "figure.child"
        case .plant:        "leaf.fill"
        case .hairAndBeard: "scissors"
        case .pet:          "pawprint.fill"
        case .fitness:      "dumbbell.fill"
        case .pregnancy:    "figure.stand"
        case .baby:         "stroller.fill"
        case .outfit:       "tshirt.fill"
        case .coupleMode:   "person.2.fill"
        case .other:        "sparkles"
        }
    }

    static func headline(_ size: CGFloat = 20) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }
    static func body(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }
    static func caption(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .medium, design: .default)
    }
    static func stamp(_ size: CGFloat = 15, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static let cornerRadius: CGFloat = 20
}

extension Color {
    init(light: String, dark: String) {
        self.init(uiColor: UIColor { trait in
            UIColor(hex: trait.userInterfaceStyle == .dark ? dark : light)
        })
    }

    func mix(with other: Color, by fraction: Double) -> Color {
        let f = min(max(fraction, 0), 1)
        let a = UIColor(self)
        let b = UIColor(other)
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        return Color(
            red: ar + (br - ar) * f,
            green: ag + (bg - ag) * f,
            blue: ab + (bb - ab) * f,
            opacity: aa + (ba - aa) * f
        )
    }
}

private extension UIColor {
    convenience init(hex: String) {
        let value = UInt64(hex, radix: 16) ?? 0
        let r = CGFloat((value & 0xFF0000) >> 16) / 255
        let g = CGFloat((value & 0x00FF00) >> 8) / 255
        let b = CGFloat(value & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

struct LiquidGlassStyle<S: InsettableShape>: ViewModifier {
    var shape: S
    var tint: Color? = nil
    var interactive: Bool = false
    var scrimOpacity: Double = 0
    var clear: Bool = false
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(shape.fill(theme.surface))
                .clipShape(shape)
                .overlay {
                    shape.strokeBorder(theme.inkMuted.opacity(0.16), lineWidth: 0.5)
                }
        } else if #available(iOS 26.0, *) {
            content
                .clipShape(shape)
                .glassEffect(glass, in: shape)
        } else {
            content
                .background {
                    if let tint {
                        ZStack {
                            shape.fill(.ultraThinMaterial)
                            shape.fill(tint)
                        }
                        .overlay {
                            LinearGradient(
                                colors: [.white.opacity(0.06), .clear],
                                startPoint: .top, endPoint: .bottom
                            )
                            .clipShape(shape)
                        }
                    } else {
                        ZStack {
                            shape.fill(.ultraThinMaterial)
                            if scrimOpacity > 0 {
                                shape.fill(theme.surface.opacity(scrimOpacity))
                            }
                        }
                        .overlay {
                            shape.strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.28), .white.opacity(0.05), .white.opacity(0.16)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.8
                            )
                        }
                    }
                }
                .clipShape(shape)
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
        }
    }

    @available(iOS 26.0, *)
    private var glass: Glass {
        var glass: Glass = clear ? .clear : .regular
        if let tint {
            glass = glass.tint(tint)
        } else if scrimOpacity > 0 {
            glass = glass.tint(theme.surface.opacity(scrimOpacity))
        }
        if interactive { glass = glass.interactive() }
        return glass
    }
}

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content.liquidGlassStyle()
    }
}

extension View {
    func liquidGlassStyle(
        cornerRadius: CGFloat = Theme.cornerRadius,
        tint: Color? = nil,
        interactive: Bool = false,
        scrimOpacity: Double = 0,
        clear: Bool = false
    ) -> some View {
        modifier(
            LiquidGlassStyle(
                shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
                tint: tint,
                interactive: interactive,
                scrimOpacity: scrimOpacity,
                clear: clear
            )
        )
    }

    func liquidGlassCapsule(tint: Color? = nil, interactive: Bool = false, scrimOpacity: Double = 0, clear: Bool = false) -> some View {
        modifier(LiquidGlassStyle(shape: Capsule(), tint: tint, interactive: interactive, scrimOpacity: scrimOpacity, clear: clear))
    }

    func liquidGlassCircle(tint: Color? = nil, interactive: Bool = false, scrimOpacity: Double = 0, clear: Bool = false) -> some View {
        modifier(LiquidGlassStyle(shape: Circle(), tint: tint, interactive: interactive, scrimOpacity: scrimOpacity, clear: clear))
    }

    func liquidGlassBar(cornerRadius: CGFloat = Theme.cornerRadius, interactive: Bool = false) -> some View {
        liquidGlassStyle(cornerRadius: cornerRadius, interactive: interactive, scrimOpacity: 0.08)
    }

    func liquidGlassBarCapsule(interactive: Bool = false) -> some View {
        liquidGlassCapsule(interactive: interactive, scrimOpacity: 0.08)
    }

    func liquidGlassBarCircle(interactive: Bool = false) -> some View {
        liquidGlassCircle(interactive: interactive, scrimOpacity: 0.08)
    }

    func cardStyle() -> some View { modifier(CardBackground()) }
    func glassSurface(cornerRadius: CGFloat = 18, tint: Color) -> some View {
        modifier(GlassSurface(cornerRadius: cornerRadius, tint: tint))
    }
}

struct GlassSurface: ViewModifier {
    var cornerRadius: CGFloat = 18
    var tint: Color

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return content
            .background {
                shape.fill(tint)
                    .overlay {
                        LinearGradient(
                            colors: [.white.opacity(0.06), .clear],
                            startPoint: .top, endPoint: .bottom
                        )
                        .clipShape(shape)
                    }
            }
            .clipShape(shape)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.headline(17))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .liquidGlassStyle(cornerRadius: 14, tint: theme.accent, interactive: true)
            .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 3)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var timelapsePrimary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

struct GlassIconButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.88 : 1)
            .opacity(configuration.isPressed ? 0.75 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == GlassIconButtonStyle {
    static var glassIcon: GlassIconButtonStyle { GlassIconButtonStyle() }
}
