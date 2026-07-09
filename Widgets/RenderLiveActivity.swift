import ActivityKit
import SwiftUI
import WidgetKit

struct RenderActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var progress: Double
        var isFinished: Bool
    }

    var title: String
}

private let flapseGreen = Color(red: 0.37, green: 0.85, blue: 0.54)

private struct FlapseIslandLogo: View {
    var size: CGFloat = 24

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(LinearGradient(
                    colors: [flapseGreen.opacity(0.85), flapseGreen],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            Circle()
                .strokeBorder(.white.opacity(0.9), lineWidth: size * 0.032)
                .padding(size * 0.14)
            WidgetApertureShape()
                .stroke(.white, style: StrokeStyle(lineWidth: size * 0.052, lineCap: .round))
                .padding(size * 0.25)
        }
        .frame(width: size, height: size)
    }
}

private struct WidgetApertureShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width, rect.height) / 2
        let innerRadius = radius / sqrt(3)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let trim = 0.72
        var path = Path()
        for i in 0..<6 {
            let startAngle = Double(i) * 60 - 90
            let targetAngle = Double(i) * 60
            let start = CGPoint(
                x: center.x + radius * cos(startAngle * .pi / 180),
                y: center.y + radius * sin(startAngle * .pi / 180)
            )
            let target = CGPoint(
                x: center.x + innerRadius * cos(targetAngle * .pi / 180),
                y: center.y + innerRadius * sin(targetAngle * .pi / 180)
            )
            let end = CGPoint(
                x: start.x + (target.x - start.x) * trim,
                y: start.y + (target.y - start.y) * trim
            )
            path.move(to: start)
            path.addLine(to: end)
        }
        return path
    }
}

private struct ProgressRing: View {
    let progress: Double
    let isFinished: Bool
    var size: CGFloat = 22
    var lineWidth: CGFloat = 2.5

    var body: some View {
        ZStack {
            if isFinished {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: size, weight: .semibold))
                    .foregroundStyle(flapseGreen)
            } else {
                Circle()
                    .stroke(flapseGreen.opacity(0.25), lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: max(progress, 0.03))
                    .stroke(flapseGreen, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(progress * 100))")
                    .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
    }
}

struct FlapseRenderLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RenderActivityAttributes.self) { context in
            lockScreenView(context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    FlapseIslandLogo(size: 36)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ProgressRing(progress: context.state.progress, isFinished: context.state.isFinished, size: 36, lineWidth: 3.5)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(context.state.isFinished ? "Timelapse hazır" : "Timelapse oluşturuluyor")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(context.attributes.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            } compactLeading: {
                FlapseIslandLogo(size: 22)
            } compactTrailing: {
                ProgressRing(progress: context.state.progress, isFinished: context.state.isFinished, size: 15, lineWidth: 2)
                    .padding(.leading, 4)
                    .padding(.trailing, 2)
            } minimal: {
                ProgressRing(progress: context.state.progress, isFinished: context.state.isFinished, size: 15, lineWidth: 2)
                    .padding(2)
            }
        }
    }

    private func lockScreenView(_ context: ActivityViewContext<RenderActivityAttributes>) -> some View {
        HStack(spacing: 12) {
            FlapseIslandLogo(size: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text(context.state.isFinished ? "Timelapse hazır" : "Timelapse oluşturuluyor…")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text(context.attributes.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            ProgressRing(progress: context.state.progress, isFinished: context.state.isFinished, size: 34, lineWidth: 3.5)
        }
        .padding(16)
        .activityBackgroundTint(Color(red: 0.06, green: 0.07, blue: 0.09))
        .activitySystemActionForegroundColor(flapseGreen)
    }
}
