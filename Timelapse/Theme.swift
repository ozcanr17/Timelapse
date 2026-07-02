import SwiftUI
import UIKit

/// Uygulamanın tek tasarım kaynağı. Palet, tipografi ve tekrar kullanılan bileşen
/// stilleri burada toplanır — FeatureGate'in para kazanma kurallarını tek dosyada
/// toplaması gibi, görsel kimlik de tek yerde yaşar.
///
/// Görsel yön: bir kontakt föyünün (contact sheet) ışık masası. Marka rengi bir film
/// negatifinin fiziksel rengidir (turuncu-kızıl taban + tamamlayıcı teal); sayılar ve
/// tarihler ise fotoğrafların köşesindeki eski tarz tarih damgasıyla (monospaced)
/// yazılır. Bu, "kategori: fotoğrafçılık" briefinden türetilmiş bir seçim — jenerik
/// sıcak-krem + serif kombinasyonundan bilinçli olarak kaçınıyoruz.
enum Theme {

    // MARK: - Renkler
    static let rust     = Color(light: "C4562F", dark: "E8825C")   // ana vurgu: negatif turuncusu
    static let teal      = Color(light: "1F6B6E", dark: "4FADAF")   // ikincil vurgu: karanlık oda tealı
    static let canvas    = Color(light: "F3F0EA", dark: "16140F")   // ışık masası zemini
    static let surface   = Color(light: "FFFFFF", dark: "211E19")   // kart yüzeyi
    static let ink       = Color(light: "241F1B", dark: "F2EEE7")   // birincil metin
    static let inkMuted  = Color(light: "6E675E", dark: "B3ABA0")   // ikincil metin

    /// Kategoriye göre vurgu rengi — liste/detay ekranlarında ikon ve rozet rengi olur.
    static func accent(for category: ProjectCategory) -> Color {
        switch category {
        case .selfPortrait: rust
        case .child:        Color(light: "B8637A", dark: "E79CAE")
        case .plant:        Color(light: "4C7A52", dark: "8FC79A")
        case .hairAndBeard: Color(light: "8A6A4E", dark: "C9A97D")
        case .pet:          Color(light: "5B7FBF", dark: "94B4F2")
        case .other:        inkMuted
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

    // MARK: - Tipografi
    // Rounded: sıcak arayüz metni. Monospaced ("damga"): gün sayısı, tarih, fiyat gibi
    // her değer — fotoğrafların köşesindeki eski tarz tarih damgasının dijital hali.
    // İkisi de SF'nin yerleşik tasarım varyantı; özel font dosyası eklemeye gerek yok.
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

private extension Color {
    /// Açık/koyu moda göre değişen adaptif renk. Hex "RRGGBB" formatında.
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

// MARK: - Tekrar kullanılan bileşen stilleri

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
    }
}

extension View {
    func cardStyle() -> some View { modifier(CardBackground()) }
}

/// Negatif turuncusu dolgulu birincil düğme. Toolbar gibi sistem alanlarında native
/// stiller kalır; bunu yalnızca markaya özgü CTA'larda (paywall, hata ekranı) kullanıyoruz.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.headline(17))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.rust)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var timelapsePrimary: PrimaryButtonStyle { PrimaryButtonStyle() }
}
