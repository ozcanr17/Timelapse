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

    func test_enAzBesTema_aydinlikGorunumuKorur() {
        let lightThemes = AppTheme.allCases.filter { $0.preferredColorScheme == .light }
        XCTAssertGreaterThanOrEqual(lightThemes.count, 5)
    }
}
