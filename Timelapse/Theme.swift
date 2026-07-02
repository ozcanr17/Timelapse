import SwiftUI
import UIKit

struct ThemePalette: Equatable {
    let accent: Color
    let secondary: Color
    let canvas: Color
    let surface: Color
    let ink: Color
    let inkMuted: Color
}

enum AppTheme: String, CaseIterable, Identifiable {
    case filmNegative = "film_negative"
    case bright
    case darkroom
    case fjord
    case lavender

    static let storageKey = "appTheme"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .filmNegative: "Negatif"
        case .bright:       "Canlı"
        case .darkroom:     "Karanlık Oda"
        case .fjord:        "Fiyort"
        case .lavender:     "Lavanta"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .darkroom: .dark
        default: nil
        }
    }

    var palette: ThemePalette {
        switch self {
        case .filmNegative:
            ThemePalette(
                accent: Color(light: "C4562F", dark: "E8825C"),
                secondary: Color(light: "1F6B6E", dark: "4FADAF"),
                canvas: Color(light: "F3F0EA", dark: "16140F"),
                surface: Color(light: "FFFFFF", dark: "211E19"),
                ink: Color(light: "241F1B", dark: "F2EEE7"),
                inkMuted: Color(light: "6E675E", dark: "B3ABA0")
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

    static let brand = Color(light: "C4562F", dark: "E8825C")

    static func accent(for category: ProjectCategory) -> Color {
        switch category {
        case .selfPortrait: Color(light: "C4562F", dark: "E8825C")
        case .child:        Color(light: "B8637A", dark: "E79CAE")
        case .plant:        Color(light: "4C7A52", dark: "8FC79A")
        case .hairAndBeard: Color(light: "8A6A4E", dark: "C9A97D")
        case .pet:          Color(light: "5B7FBF", dark: "94B4F2")
        case .other:        Color(light: "6E675E", dark: "B3ABA0")
        }
    }

    static func icon(for category: ProjectCategory) -> String {
        switch category {
        case .selfPortrait: "person.crop.circle"
        case .child:        "figure.child"
        case .plant:        "leaf.fill"
        case .hairAndBeard: "scissors"
        case .pet:          "pawprint.fill"
        case .other:        "sparkles"
        }
    }

    static func headline(_ size: CGFloat = 20) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
    static func body(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .regular, design: .rounded)
    }
    static func caption(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
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

struct CardBackground: ViewModifier {
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        content
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
    }
}

extension View {
    func cardStyle() -> some View { modifier(CardBackground()) }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.theme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.headline(17))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var timelapsePrimary: PrimaryButtonStyle { PrimaryButtonStyle() }
}
