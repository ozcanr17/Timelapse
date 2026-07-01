import SwiftUI
import SwiftData
import UIKit   // UIImage için

/// Bir projenin çekimlerini kronolojik ızgara olarak gösteren detay ekranı.
struct ProjectDetailView: View {

    // `project` canlı bir @Model nesnesi. @Observable olduğu için, aynı context
    // üzerinden çekim eklendiğinde project.entries değişir ve bu ekran kendiliğinden
    // tazelenir — elle yeniden yükleme gerekmez.
    let project: Project

    @Environment(\.modelContext) private var modelContext

    @State private var isCapturing = false

    // Ekran genişliğine göre sütun sayısını kendi ayarlayan esnek ızgara.
    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if project.sortedEntries.isEmpty {
                    ContentUnavailableView(
                        "Henüz çekim yok",
                        systemImage: "camera",
                        description: Text("Sağ üstteki düğmeyle ilk çekimini ekle.")
                    )
                    .padding(.top, 40)
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        // enumerated() ile sıra numarasını (kaçıncı gün) da alıyoruz.
                        ForEach(Array(project.sortedEntries.enumerated()), id: \.element.id) { index, entry in
                            EntryThumbnail(entry: entry, dayNumber: index + 1)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(project.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isCapturing = true
                } label: {
                    Label("Çekim ekle", systemImage: "plus.circle.fill")
                }
            }
        }
        // Kamerayı tam ekran aç. Kaydetme işini kameranın ViewModel'i repository üzerinden
        // yapar; aynı context kullanıldığı için dönünce ızgara kendiliğinden güncellenir.
        .fullScreenCover(isPresented: $isCapturing) {
            CameraCaptureView(
                camera: CameraService(),
                repository: ProjectRepository(context: modelContext),
                project: project
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(project.category.displayName)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Label("\(project.sortedEntries.count) çekim", systemImage: "photo.stack")
                Label(project.cadence.displayName, systemImage: "calendar")
            }
            .font(.subheadline)

            if project.isCaptureDue() {
                Text("Bugün çekim zamanı geldi")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.tint)
            }
        }
    }
}

/// Izgaradaki tek bir çekim karesi. Fotoğraf varsa onu, yoksa yer tutucu gösterir.
private struct EntryThumbnail: View {
    let entry: Entry
    let dayNumber: Int

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                if let data = entry.imageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle().fill(.quaternary)
                    Image(systemName: "camera")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 100)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Text(entry.capturedAt, format: .dateTime.day().month())
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .overlay(alignment: .topLeading) {
            Text("\(dayNumber)")
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(6)
        }
    }
}

#Preview {
    // Önizleme için bellek içi bir proje + birkaç örnek çekim hazırlıyoruz.
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
