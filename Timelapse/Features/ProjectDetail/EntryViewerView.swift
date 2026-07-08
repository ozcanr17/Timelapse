import SwiftUI
import SwiftData
import UIKit
import Photos

struct EntryViewerView: View {

    let project: Project

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @Environment(StoreService.self) private var store

    @State private var selectedEntryID: UUID
    @State private var isConfirmingDelete = false
    @State private var retakeTarget: Entry?
    @State private var shareImage: UIImage?

    init(project: Project, initialEntry: Entry) {
        self.project = project
        _selectedEntryID = State(initialValue: initialEntry.id)
    }

    private var entries: [Entry] {
        let live = project.sortedEntries.filter { !$0.isDeleted }
        guard !store.isPro else { return live }
        return Array(live.suffix(FeatureGate.freeEntryLimit))
    }

    private var selectedEntry: Entry? {
        entries.first { $0.id == selectedEntryID }
    }

    private var selectedIndex: Int? {
        entries.firstIndex { $0.id == selectedEntryID }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $selectedEntryID) {
                ForEach(entries) { entry in
                    EntryPage(entry: entry)
                        .tag(entry.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            VStack {
                topBar
                Spacer()
                metadataBar
                bottomBar
            }
        }
        .environment(\.colorScheme, .dark)
        .confirmationDialog(
            "Bu çekim kalıcı olarak silinsin mi?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Sil", role: .destructive) { deleteSelected() }
            Button("Vazgeç", role: .cancel) {}
        }
        .fullScreenCover(item: $retakeTarget) { entry in
            CameraCaptureView(project: project, retakeEntry: entry)
        }
    }

    private var topBar: some View {
        HStack {
            CameraControlButton(icon: "xmark", label: "Kapat") { dismiss() }
            Spacer()
            if let index = selectedIndex {
                Text(String(format: "No. %02d", index + 1))
                    .font(Theme.stamp(13))
                    .foregroundStyle(.white)
            }
            Spacer()
            HStack(spacing: 10) {
                if let shareImage {
                    ShareLink(item: Image(uiImage: shareImage), preview: SharePreview("Kare", image: Image(uiImage: shareImage))) {
                        controlIcon("square.and.arrow.up")
                    }
                    .accessibilityLabel(Text("Kareyi paylaş"))
                }
                Button { saveToPhotos() } label: { controlIcon("square.and.arrow.down") }
                    .accessibilityLabel(Text("Fotoğraflara kaydet"))
                Button { isConfirmingDelete = true } label: { controlIcon("trash") }
                    .accessibilityLabel(Text("Kareyi sil"))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .task(id: selectedEntryID) {
            shareImage = await ImageDownsampler.image(from: selectedEntry?.imageData, maxPixelSize: 3000)
        }
    }

    private func controlIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 42, height: 42)
            .background(.ultraThinMaterial, in: Circle())
    }

    private func saveToPhotos() {
        guard let image = shareImage else { return }
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        } completionHandler: { success, _ in
            Task { @MainActor in
                UINotificationFeedbackGenerator().notificationOccurred(success ? .success : .error)
            }
        }
    }

    @ViewBuilder
    private var metadataBar: some View {
        if let entry = selectedEntry {
            VStack(spacing: 6) {
                Text(entry.capturedAt, format: .dateTime.weekday(.wide).day().month().year())
                    .font(Theme.headline(15))
                HStack(spacing: 16) {
                    Label(entry.capturedAt.formatted(.dateTime.hour().minute()), systemImage: "clock")
                    if let place = entry.placeName, !place.isEmpty {
                        Label(place, systemImage: "mappin.and.ellipse").lineLimit(1)
                    }
                }
                .font(Theme.caption(13))
                .foregroundStyle(.white.opacity(0.85))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.bottom, 8)
        }
    }

    private var bottomBar: some View {
        Button {
            retakeTarget = selectedEntry
        } label: {
            Label("Yeniden Çek", systemImage: "camera.badge.clock")
                .font(Theme.headline(15))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(theme.accent, in: Capsule())
        }
        .padding(.bottom, 20)
    }

    private func deleteSelected() {
        guard let entry = selectedEntry else { return }
        let index = selectedIndex ?? 0
        let repository = ProjectRepository(context: modelContext)
        withAnimation {
            try? repository.deleteEntry(entry)
        }
        Task {
            try? await Task.sleep(for: .seconds(0.6))
            try? repository.saveIfNeeded()
        }

        let remaining = entries
        if remaining.isEmpty {
            dismiss()
        } else {
            selectedEntryID = remaining[min(index, remaining.count - 1)].id
        }
    }
}

private struct EntryPage: View {
    let entry: Entry

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: entry.imageData?.count) {
            image = await ImageDownsampler.image(from: entry.imageData, maxPixelSize: 2400)
        }
    }
}
