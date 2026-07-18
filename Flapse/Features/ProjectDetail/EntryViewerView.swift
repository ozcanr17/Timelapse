import SwiftUI
import SwiftData
import UIKit
import Photos

struct EntryViewerView: View {

    let project: Project
    let sourceEntries: [Entry]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @Environment(StoreService.self) private var store

    @State private var selectedEntryID: UUID
    @State private var isConfirmingDelete = false
    @State private var retakeTarget: Entry?
    @State private var editTarget: Entry?
    @State private var shareImage: UIImage?
    @State private var showPhotosDenied = false

    init(project: Project, initialEntry: Entry, entries: [Entry]) {
        self.project = project
        sourceEntries = entries
        _selectedEntryID = State(initialValue: initialEntry.id)
    }

    private var entries: [Entry] {
        let live = sourceEntries.filter { !$0.isDeleted }
        guard !store.isPro else { return live }
        return Array(live.suffix(FeatureGate.freeEntryLimit))
    }

    private var pageEntries: ArraySlice<Entry> {
        let available = entries
        guard let index = available.firstIndex(where: { $0.id == selectedEntryID }) else { return [] }
        let lower = max(available.startIndex, index - 1)
        let upper = min(available.endIndex, index + 2)
        return available[lower..<upper]
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
                ForEach(pageEntries) { entry in
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
        .fullScreenCover(item: $editTarget) { entry in
            PhotoEditView(imageData: entry.imageData) { data in
                let repository = ProjectRepository(context: modelContext)
                try? repository.replaceImage(for: entry, with: data)
            }
        }
        .photosDeniedAlert(isPresented: $showPhotosDenied)
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
                Button { editTarget = selectedEntry } label: { controlIcon("slider.horizontal.3") }
                    .accessibilityLabel(Text("Fotoğrafı düzenle"))
                Button { saveToPhotos() } label: { controlIcon("square.and.arrow.down") }
                    .accessibilityLabel(Text("Fotoğraflara kaydet"))
                Button { isConfirmingDelete = true } label: { controlIcon("trash") }
                    .accessibilityLabel(Text("Kareyi sil"))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .task(id: selectedEntry?.imageCacheKey) {
            guard let entry = selectedEntry else {
                shareImage = nil
                return
            }
            shareImage = await ImageDownsampler.cachedImage(
                key: "viewer-\(entry.imageCacheKey)",
                maxPixelSize: 2400,
                load: { entry.imageData }
            )
        }
    }

    private func controlIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 42, height: 42)
            .liquidGlassBarCircle()
    }

    private func saveToPhotos() {
        guard let image = shareImage else { return }
        Task {
            let outcome = await PhotoLibrarySaver.saveImage(image)
            if outcome == .denied {
                showPhotosDenied = true
            }
            UINotificationFeedbackGenerator().notificationOccurred(outcome == .saved ? .success : .error)
        }
    }

    @ViewBuilder
    private var metadataBar: some View {
        if let entry = selectedEntry {
            VStack(spacing: 6) {
                Text(entry.capturedAt, format: .dateTime.weekday(.wide).day().month().year())
                    .font(Theme.headline(15))
                HStack(spacing: 16) {
                    Label(entry.capturedAt.formatted(.dateTime.hour().minute().locale(AppLanguage.currentLocale)), systemImage: "clock")
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
    @State private var zoom: CGFloat = 1
    @State private var pinchBase: CGFloat?
    @State private var offset: CGSize = .zero
    @State private var dragBase: CGSize?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(zoom)
                    .offset(offset)
                    .gesture(zoomGesture)
                    .simultaneousGesture(zoom > 1 ? panGesture : nil)
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                            if zoom > 1 {
                                zoom = 1
                                offset = .zero
                            } else {
                                zoom = 2.4
                            }
                        }
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.9), value: zoom == 1)
            } else {
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: entry.imageCacheKey) {
            image = await ImageDownsampler.cachedImage(
                key: "viewer-\(entry.imageCacheKey)",
                maxPixelSize: 2400,
                load: { entry.imageData }
            )
        }
        .onChange(of: entry.id) {
            zoom = 1
            offset = .zero
        }
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                if pinchBase == nil { pinchBase = zoom }
                zoom = min(max((pinchBase ?? 1) * value, 1), 5)
            }
            .onEnded { _ in
                pinchBase = nil
                if zoom <= 1.02 {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                        zoom = 1
                        offset = .zero
                    }
                }
            }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if dragBase == nil { dragBase = offset }
                let base = dragBase ?? .zero
                offset = CGSize(width: base.width + value.translation.width, height: base.height + value.translation.height)
            }
            .onEnded { _ in dragBase = nil }
    }
}
