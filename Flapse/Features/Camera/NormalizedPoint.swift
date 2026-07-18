import CoreGraphics

/// 0...1 aralığında normalize edilmiş bir nokta. Çözünürlükten ve ekran boyutundan
/// bağımsız olduğu için aynı referans noktası farklı karelerde/cihazlarda hep aynı
/// göreli yere denk gelir. (Entry'deki anchorX/anchorY bu şekilde saklanır.)
struct NormalizedPoint: Equatable {
    let x: Double
    let y: Double

    init(x: Double, y: Double) {
        // Dışarıdan ne gelirse gelsin değerleri 0...1 aralığında tutuyoruz.
        self.x = Self.clamp(x)
        self.y = Self.clamp(y)
    }

    /// Verilen boyuttaki gerçek (point) konuma çevirir — çizim/yerleştirme için.
    func cgPoint(in size: CGSize) -> CGPoint {
        CGPoint(x: x * size.width, y: y * size.height)
    }

    /// Verilen boyuttaki bir dokunma konumunu normalize noktaya çevirir.
    static func from(_ point: CGPoint, in size: CGSize) -> NormalizedPoint {
        guard size.width > 0, size.height > 0 else { return NormalizedPoint(x: 0.5, y: 0.5) }
        return NormalizedPoint(x: Double(point.x / size.width),
                               y: Double(point.y / size.height))
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
