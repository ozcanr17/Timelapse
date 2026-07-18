import SwiftUI

struct LogoMark: View {
    var size: CGFloat = 96
    /// Yalnızca içteki objektif (aperture) döner; dıştaki yuvarlatılmış kare sabit kalır.
    var innerRotation: Angle = .zero

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(LinearGradient(
                    colors: [Theme.brand.opacity(0.85), Theme.brand],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            ZStack {
                Circle()
                    .strokeBorder(.white.opacity(0.9), lineWidth: size * 0.032)
                    .padding(size * 0.14)
                ApertureShape()
                    .stroke(.white, style: StrokeStyle(lineWidth: size * 0.052, lineCap: .round))
                    .padding(size * 0.25)
            }
            .rotationEffect(innerRotation)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.12), radius: size * 0.1, x: 0, y: size * 0.04)
    }
}

struct ApertureShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width, rect.height) / 2
        let innerRadius = radius / sqrt(3)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let trim = 0.72
        var path = Path()
        for i in 0..<6 {
            let start = point(center: center, radius: radius, angle: radians(Double(i) * 60 - 90))
            let target = point(center: center, radius: innerRadius, angle: radians(Double(i) * 60))
            let end = CGPoint(
                x: start.x + (target.x - start.x) * trim,
                y: start.y + (target.y - start.y) * trim
            )
            path.move(to: start)
            path.addLine(to: end)
        }
        return path
    }

    private func radians(_ degrees: Double) -> Double {
        degrees * .pi / 180
    }

    private func point(center: CGPoint, radius: CGFloat, angle: Double) -> CGPoint {
        CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
    }
}

#Preview {
    LogoMark(size: 160)
        .padding(40)
        .background(AppTheme.filmNegative.palette.canvas)
}
