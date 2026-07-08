import SwiftUI

/// "Önce & Sonra" paylaşım kartı: ilk ve son kare yan yana, aradaki gün sayısı ortada.
struct CompareShareCard: View {

    let title: String
    let firstImage: UIImage
    let lastImage: UIImage
    let firstDate: Date
    let lastDate: Date
    let theme: ThemePalette

    private var dayCount: Int {
        max(1, Calendar.current.dateComponents([.day], from: firstDate, to: lastDate).day ?? 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                panel(image: firstImage, label: String(localized: "GÜN 1", bundle: .appLanguage), date: firstDate)
                panel(image: lastImage, label: String(localized: "BUGÜN", bundle: .appLanguage), date: lastDate)
            }
            .overlay {
                VStack(spacing: 2) {
                    Text("\(dayCount)")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                    Text("GÜN", bundle: .appLanguage)
                        .font(.system(size: 13, weight: .bold))
                        .tracking(3)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
                .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }

            HStack {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(theme.ink)
                Spacer()
                HStack(spacing: 7) {
                    LogoMark(size: 26)
                    Text("Flapse")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.inkMuted)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .background(theme.canvas)
        }
        .frame(width: 800)
        .background(theme.canvas)
    }

    private func panel(image: UIImage, label: String, date: Date) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: 398, height: 500)
            .clipped()
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 13, weight: .heavy))
                        .tracking(1.5)
                    Text(date, format: .dateTime.day().month().year().locale(AppLanguage.currentLocale))
                        .font(.system(size: 11, weight: .semibold))
                        .opacity(0.85)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(10)
            }
    }
}
