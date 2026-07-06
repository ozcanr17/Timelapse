import SwiftUI

struct AnimatedAccentBackground: View {
    let base: Color

    var body: some View {
        if #available(iOS 18.0, *) {
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.5], [0.58, 0.55], [1, 0.5],
                    [0, 1], [0.5, 1], [1, 1]
                ],
                colors: [
                    base,
                    base.mix(with: .white, by: 0.14),
                    base.mix(with: .black, by: 0.08),
                    base.mix(with: .black, by: 0.08),
                    base.mix(with: .white, by: 0.20),
                    base.mix(with: .black, by: 0.14),
                    base.mix(with: .black, by: 0.20),
                    base.mix(with: .white, by: 0.06),
                    base.mix(with: .black, by: 0.16)
                ]
            )
        } else {
            LinearGradient(
                colors: [base, base.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
