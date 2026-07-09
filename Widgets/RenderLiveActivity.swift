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
        Image("AppLogo")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
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
