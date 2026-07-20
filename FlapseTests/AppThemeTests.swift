import SwiftUI
import XCTest
@testable import Flapse

final class AppThemeTests: XCTestCase {

    func test_tumTemalar_rawValueIleGeriYuklenebilir() {
        for theme in AppTheme.allCases {
            XCTAssertEqual(AppTheme(rawValue: theme.rawValue), theme)
        }
    }

    func test_temaVurgulari_birbirindenFarklidir() {
        let accents = AppTheme.allCases.map(\.palette.accent)
        XCTAssertEqual(Set(accents).count, AppTheme.allCases.count)
    }

    func test_varsayilanTema_filmNegatifidir() {
        XCTAssertEqual(AppTheme(rawValue: "film_negative"), .filmNegative)
    }

    func test_altiHazirTema_ucAcikUcKoyuOlarakDagilir() {
        XCTAssertEqual(AppTheme.allCases.count, 6)
        let lightThemes = AppTheme.allCases.filter { $0.preferredColorScheme == .light }
        let darkThemes = AppTheme.allCases.filter { $0.preferredColorScheme == .dark }
        XCTAssertEqual(lightThemes.count, 3)
        XCTAssertEqual(darkThemes.count, 3)
    }

    func test_eskiTemaKimlikleri_enYakinYeniPaleteTasinir() {
        XCTAssertEqual(AppTheme.resolved(storedID: "daylight"), .coastal)
        XCTAssertEqual(AppTheme.resolved(storedID: "bright"), .paper)
        XCTAssertEqual(AppTheme.resolved(storedID: "lavender"), .filmNegative)
    }

    func test_ozelTema_birincilVeIkincilRenkleriUygular() {
        let configuration = ThemePreference.configuration(
            themeID: AppTheme.filmNegative.rawValue,
            customEnabled: true,
            primaryHex: "101820",
            secondaryHex: "FF6B6B"
        )

        XCTAssertEqual(configuration.preferredColorScheme, .dark)
        XCTAssertEqual(configuration.palette.canvas.hexRGB, "101820")
        XCTAssertEqual(configuration.palette.accent.hexRGB, "FF6B6B")
    }
}
