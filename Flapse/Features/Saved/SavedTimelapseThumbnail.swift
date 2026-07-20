import SwiftData
import SwiftUI
import UIKit

struct SavedTimelapseThumbnail: View {
    let item: SavedTimelapse
    let maxPixelSize: CGFloat

    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            theme.inkMuted.opacity(0.1)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "film")
                    .foregroundStyle(theme.inkMuted)
            }
        }
        .task(id: "\(item.id.uuidString)-\(item.posterData?.count ?? 0)") {
            if let stored = await loadStoredPoster() {
                image = stored
                return
            }
            guard let generated = await TimelapseLibrary.makePosterData(
                videoURL: item.fileURL,
                duration: item.duration
            ) else { return }
            item.posterData = generated
            try? modelContext.save()
            image = await ImageDownsampler.cachedImage(
                key: "saved-video-\(item.id.uuidString)-\(generated.count)",
                maxPixelSize: maxPixelSize,
                load: { generated }
            )
        }
    }

    private func loadStoredPoster() async -> UIImage? {
        guard let data = item.posterData else { return nil }
        return await ImageDownsampler.cachedImage(
            key: "saved-video-\(item.id.uuidString)-\(data.count)",
            maxPixelSize: maxPixelSize,
            load: { data }
        )
    }
}
