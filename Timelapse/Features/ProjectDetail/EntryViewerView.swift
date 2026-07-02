import SwiftUI
import SwiftData
import UIKit

struct EntryViewerView: View {

    let project: Project

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    @State private var selectedEntryID: UUID
    @State private var isConfirmingDelete = false
    @State private var retakeTarget: Entry?

    init(project: Project, initialEntry: Entry) {
        self.project = project
        _selectedEntryID = State(initialValue: initialEntry.id)
    }

    private var entries: [Entry] { project.sortedEntries }

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
            CameraControlButton(icon: "xmark") { dismiss() }
            Spacer()
            if let index = selectedIndex, let entry = selectedEntry {
                VStack(spacing: 2) {
                    Text(String(format: "No. %02d", index + 1))
                        .font(Theme.stamp(13))
                    Text(entry.capturedAt, format: .dateTime.day().month().year())
                        .font(Theme.caption(11))
                        .opacity(0.75)
                }
                .foregroundStyle(.white)
            }
            Spacer()
            CameraControlButton(icon: "trash") { isConfirmingDelete = true }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
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
        try? repository.deleteEntry(entry)

        let remaining = project.sortedEntries
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
