import Vision
import UIKit

/// Bir karedeki hizalama çıpası: özne (yüz) kutusunun normalize (0…1) merkezi ve
/// yüksekliği. Origin sol-üsttür.
struct FrameAnchor: Equatable {
    let center: CGPoint
    let height: CGFloat
}

/// Akıllı Hizalama'nın beyni: Vision ile her karedeki en büyük yüzü bulur. Bu çıpalar
/// kullanılarak dışa aktarımda özne ardışık karelerde aynı konum ve boyuta sabitlenir —
/// böylece "hayalet" (ghost) el yordamı yerine gerçek, otomatik hizalama elde edilir.
enum FrameAligner {

    /// Karedeki en büyük yüzün çıpası (yoksa nil). Senkron çalışır; composer'ın arka
    /// plan render görevinden güvenle çağrılır.
    static func anchor(in imageData: Data) -> FrameAnchor? {
        guard let image = UIImage(data: imageData), let cgImage = image.cgImage else { return nil }

        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: cgOrientation(from: image.imageOrientation),
            options: [:]
        )
        try? handler.perform([request])

        guard
            let faces = request.results,
            let largest = faces.max(by: { $0.boundingBox.height < $1.boundingBox.height })
        else { return nil }

        // Vision normalize koordinatlarında origin SOL-ALT; sol-üste çeviriyoruz.
        let box = largest.boundingBox
        return FrameAnchor(
            center: CGPoint(x: box.midX, y: 1 - box.midY),
            height: box.height
        )
    }

    private static func cgOrientation(from orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up:            .up
        case .upMirrored:    .upMirrored
        case .down:          .down
        case .downMirrored:  .downMirrored
        case .left:          .left
        case .leftMirrored:  .leftMirrored
        case .right:         .right
        case .rightMirrored: .rightMirrored
        @unknown default:    .up
        }
    }
}
