import SwiftUI

struct WelcomeView: View {

    let onFinish: () -> Void

    @Environment(\.theme) private var theme
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            theme.canvas.ignoresSafeArea()
            AnimatedAccentBackground(base: theme.accent)
                .opacity(isAnimating ? 0.14 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer()

                LogoMark(size: 116)
                    .rotationEffect(.degrees(isAnimating ? 0 : -120))
                    .scaleEffect(isAnimating ? 1 : 0.6)
                    .opacity(isAnimating ? 1 : 0)
                    .animation(.spring(response: 0.9, dampingFraction: 0.7), value: isAnimating)

                Text("Flapse")
                    .font(Theme.headline(34))
                    .foregroundStyle(theme.ink)
                    .padding(.top, 24)

                Text("DEĞİŞİMİ TEK KAREDE BİRİKTİR")
                    .font(Theme.caption(12))
                    .foregroundStyle(theme.inkMuted)
                    .tracking(2)
                    .padding(.top, 6)

                VStack(alignment: .leading, spacing: 18) {
                    WelcomeFeatureRow(
                        icon: "wand.and.stars",
                        title: "Akıllı hizalama",
                        subtitle: "Pro'da özneyi otomatik hizala; kareler pürüzsüz aksın"
                    )
                    WelcomeFeatureRow(
                        icon: "calendar.badge.clock",
                        title: "Kadans takibi",
                        subtitle: "Her gün, gün aşırı ya da haftalık — zamanı gelince hatırla"
                    )
                    WelcomeFeatureRow(
                        icon: "film.stack",
                        title: "Timelapse videosu",
                        subtitle: "Karelerini tek dokunuşla videoya dönüştür ve paylaş"
                    )
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
                .padding(.horizontal, 24)
                .padding(.top, 36)

                Spacer()

                Button("Başla") { onFinish() }
                    .buttonStyle(.timelapsePrimary)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }
        }
        .onAppear { isAnimating = true }
    }
}

private struct WelcomeFeatureRow: View {
    let icon: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(theme.accent.opacity(0.12)).frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.accent)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Theme.headline(15))
                    .foregroundStyle(theme.ink)
                Text(subtitle)
                    .font(Theme.caption(12))
                    .foregroundStyle(theme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    WelcomeView {}
}
