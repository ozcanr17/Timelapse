import SwiftUI

/// Reels/TikTok/Story için hazır 9:16 (1080×1920) "Önce → Sonra" kartı: ilk kare
/// üstte, son kare altta; ortadaki rozet geçen gün sayısını söyler.
struct StoryShareCard: View {

    let title: String
    let firstImage: UIImage
    let lastImage: UIImage
    let firstDate: Date
    let lastDate: Date
    let theme: ThemePalette

    private var dayCount: Int {
        max(1, (Calendar.current.dateComponents([.day], from: firstDate, to: lastDate).day ?? 0) + 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            panel(image: firstImage, label: String(localized: "GÜN 1", bundle: .appLanguage), date: firstDate, alignment: .topLeading)
            panel(image: lastImage, label: String(localized: "GÜN \(dayCount)", bundle: .appLanguage), date: lastDate, alignment: .bottomLeading)
        }
        .overlay {
            VStack(spacing: 4) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 40, weight: .bold))
                Text("\(dayCount)")
                    .font(.system(size: 92, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                Text("GÜN", bundle: .appLanguage)
                    .font(.system(size: 26, weight: .bold))
                    .tracking(6)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 52)
            .padding(.vertical, 36)
            .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 44, style: .continuous))
        }
        .overlay(alignment: .bottom) {
            HStack(spacing: 14) {
                LogoMark(size: 52)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 30, weight: .bold))
                        .lineLimit(1)
                    Text("Made with Flapse")
                        .font(.system(size: 20, weight: .semibold))
                        .opacity(0.75)
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 30)
            .padding(.vertical, 20)
            .background(.black.opacity(0.55), in: Capsule())
            .padding(.bottom, 100)
        }
        .frame(width: 1080, height: 1920)
        .background(Color.black)
    }

    private func panel(image: UIImage, label: String, date: Date, alignment: Alignment) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: 1080, height: 960)
            .clipped()
            .overlay(alignment: alignment) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(label)
                        .font(.system(size: 30, weight: .heavy))
                        .tracking(2)
                    Text(date, format: .dateTime.day().month().year().locale(AppLanguage.currentLocale))
                        .font(.system(size: 22, weight: .semibold))
                        .opacity(0.85)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .padding(28)
            }
    }
}
