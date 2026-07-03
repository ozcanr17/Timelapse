import SwiftUI

struct StreakShareCard: View {
    let project: Project
    let theme: ThemePalette

    private var dates: [Date] { project.sortedEntries.map(\.capturedAt) }
    private var streak: Int { ActivitySummary.streak(capturedDates: dates) }
    private var total: Int { dates.count }
    private var daysRunning: Int { ActivitySummary.daysRunning(firstCapture: dates.first) }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [theme.accent, theme.accent.mix(with: .black, by: 0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 0) {
                LogoMark(size: 56)
                    .padding(.top, 64)

                Spacer()

                Text(project.category.displayName.uppercased())
                    .font(Theme.caption(18))
                    .tracking(3)
                    .foregroundStyle(.white.opacity(0.75))

                Text(project.title)
                    .font(Theme.headline(52))
                    .foregroundStyle(.white)
                    .padding(.top, 6)
                    .lineLimit(1)

                HStack(spacing: 40) {
                    ShareStatColumn(value: "\(streak)", label: "GÜN SERİSİ")
                    ShareStatColumn(value: "\(total)", label: "TOPLAM KARE")
                    ShareStatColumn(value: "\(daysRunning)", label: "GÜNDÜR")
                }
                .padding(.top, 36)

                Spacer()

                HStack(spacing: 10) {
                    Image(systemName: "camera.aperture")
                        .foregroundStyle(.white.opacity(0.85))
                    Text("Timelapse ile takip ediyorum")
                        .font(Theme.stamp(16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.bottom, 56)
            }
            .padding(.horizontal, 64)
        }
        .frame(width: 1080, height: 1350)
    }
}

private struct ShareStatColumn: View {
    let value: String
    let label: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(Theme.stamp(44, weight: .bold))
                .foregroundStyle(.white)
            Text(label)
                .font(Theme.caption(13))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}

#Preview {
    let project = Project(title: "Sakal", category: .hairAndBeard, cadence: .daily)
    return StreakShareCard(project: project, theme: AppTheme.cyber.palette)
        .frame(width: 320, height: 400)
        .scaleEffect(0.3)
}
