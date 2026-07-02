import SwiftUI
import SwiftData
import UIKit

/// Bir projenin çekimlerini kontakt föyü (contact sheet) mantığıyla ızgara olarak
/// gösteren detay ekranı.
struct ProjectDetailView: View {

    let project: Project
    @Environment(\.modelContext) private var modelContext
    @State private var isCapturing = false

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]
    private var accent: Color { Theme.accent(for: project.category) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if project.sortedEntries.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Array(project.sortedEntries.enumerated()), id: \.element.id) { index, entry in
                            EntryThumbnail(entry: entry, dayNumber: index + 1, accent: accent)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Theme.canvas.ignoresSafeArea())
        .navigationTitle(project.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isCapturing = true
                } label: {
                    Image(systemName: "camera.fill")
                        .foregroundStyle(accent)
                }
            }
        }
        .fullScreenCover(isPresented: $isCapturing) {
            CameraCaptureView(
                camera: CameraService(),
                repository: ProjectRepository(context: modelContext),
                project: project
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(project.category.displayName.uppercased())
                        .font(Theme.caption(12))
                        .foregroundStyle(.white.opacity(0.8))
                        .tracking(1.2)

                    (
                        Text("\(project.sortedEntries.count)")
                            .font(Theme.stamp(40, weight: .bold))
                            .foregroundStyle(.white)
                        +
                        Text(" çekim")
                            .font(Theme.headline(17))
                            .foregroundStyle(.white.opacity(0.85))
                    )
                }
                Spacer()
                ZStack {
                    Circle().fill(.white.opacity(0.18)).frame(width: 54, height: 54)
                    Image(systemName: Theme.icon(for: project.category))
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }

            HStack(spacing: 14) {
                Label(project.cadence.displayName, systemImage: "calendar")
                if project.isCaptureDue() {
                    Label("Bugün zamanı geldi", systemImage: "bell.fill")
                }
            }
            .font(Theme.caption(12))
            .foregroundStyle(.white.opacity(0.9))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [accent, accent.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera")
                .font(.system(size: 30))
                .foregroundStyle(Theme.inkMuted)
            Text("Henüz çekim yok")
                .font(Theme.headline(16))
                .foregroundStyle(Theme.ink)
            Text("Sağ üstteki kamera düğmesiyle ilk çekimini ekle.")
                .font(Theme.body(14))
                .foregroundStyle(Theme.inkMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 50)
    }
}

/// Kontakt föyündeki tek bir kare: fotoğraf + "No. 0X" damgası — gerçek bir negatifin
/// köşesindeki eski tarz numaralandırmaya gönderme.
private struct EntryThumbnail: View {
    let entry: Entry
    let dayNumber: Int
    let accent: Color

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                if let data = entry.imageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage).resizable().scaledToFill()
                } else {
                    Rectangle().fill(Theme.surface)
                    Image(systemName: "camera")
                        .foregroundStyle(Theme.inkMuted)
                }
            }
            .frame(height: 110)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Theme.ink.opacity(0.06), lineWidth: 1)
            )
            .overlay(alignment: .topLeading) {
                Text(String(format: "No. %02d", dayNumber))
                    .font(Theme.stamp(9.5, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(accent.opacity(0.88))
                    .clipShape(Capsule())
                    .padding(6)
            }
            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)

            Text(entry.capturedAt, format: .dateTime.day().month())
                .font(Theme.stamp(11, weight: .regular))
                .foregroundStyle(Theme.inkMuted)
        }
    }
}

#Preview {
    let container = AppModelContainer.makeInMemory()
    let project = Project(title: "Sakal", category: .hairAndBeard, cadence: .daily)
    container.mainContext.insert(project)
    for dayOffset in 0..<5 {
        let entry = Entry(capturedAt: .now.addingTimeInterval(Double(-dayOffset) * 86_400))
        entry.project = project
        container.mainContext.insert(entry)
    }
    return NavigationStack {
        ProjectDetailView(project: project)
    }
    .modelContainer(container)
}
