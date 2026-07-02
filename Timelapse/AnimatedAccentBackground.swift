import SwiftUI

struct AnimatedAccentBackground: View {
    let base: Color

    var body: some View {
        if #available(iOS 18.0, *) {
            TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                MeshGradient(
                    width: 3,
                    height: 3,
                    points: [
                        [0, 0], [0.5, 0], [1, 0],
                        [0, 0.5],
                        [
                            0.5 + 0.22 * Float(sin(t * 0.55)),
                            0.5 + 0.22 * Float(cos(t * 0.45))
                        ],
                        [1, 0.5],
                        [0, 1], [0.5, 1], [1, 1]
                    ],
                    colors: [
                        base,
                        base.mix(with: .white, by: 0.16),
                        base.mix(with: .black, by: 0.08),
                        base.mix(with: .black, by: 0.10),
                        base.mix(with: .white, by: 0.28),
                        base.mix(with: .black, by: 0.16),
                        base.mix(with: .black, by: 0.24),
                        base.mix(with: .white, by: 0.06),
                        base.mix(with: .black, by: 0.20)
                    ]
                )
            }
        } else {
            LinearGradient(
                colors: [base, base.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
