import XCTest
import CoreGraphics
@testable import Flapse   // ← kendi hedef (target) adınla değiştir

/// Hizalamanın saf matematiği. Hiçbir arayüze veya donanıma bağlı olmadığı için
/// testler hızlı ve güvenilir.
final class NormalizedPointTests: XCTestCase {

    func test_cgPoint_boyutaGoreOlcekler() {
        let p = NormalizedPoint(x: 0.5, y: 0.25)
        let cg = p.cgPoint(in: CGSize(width: 200, height: 400))
        XCTAssertEqual(cg.x, 100, accuracy: 0.001)
        XCTAssertEqual(cg.y, 100, accuracy: 0.001)
    }

    func test_from_dokunmayiNormalizeEder() {
        let p = NormalizedPoint.from(CGPoint(x: 50, y: 300), in: CGSize(width: 200, height: 400))
        XCTAssertEqual(p.x, 0.25, accuracy: 0.001)
        XCTAssertEqual(p.y, 0.75, accuracy: 0.001)
    }

    func test_sinirDisiDegerler_0_1ArasinaKisilir() {
        let p = NormalizedPoint(x: 1.5, y: -0.3)
        XCTAssertEqual(p.x, 1.0, accuracy: 0.001)
        XCTAssertEqual(p.y, 0.0, accuracy: 0.001)
    }

    func test_gidisDonus_tutarlidir() {
        let size = CGSize(width: 320, height: 480)
        let original = NormalizedPoint(x: 0.3, y: 0.8)
        let roundTrip = NormalizedPoint.from(original.cgPoint(in: size), in: size)
        XCTAssertEqual(roundTrip.x, original.x, accuracy: 0.001)
        XCTAssertEqual(roundTrip.y, original.y, accuracy: 0.001)
    }

    func test_sifirBoyut_guvenliVarsayilanDoner() {
        let p = NormalizedPoint.from(CGPoint(x: 10, y: 10), in: .zero)
        XCTAssertEqual(p.x, 0.5, accuracy: 0.001)
        XCTAssertEqual(p.y, 0.5, accuracy: 0.001)
    }
}
