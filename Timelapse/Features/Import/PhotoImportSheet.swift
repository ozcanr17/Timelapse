import SwiftUI
import PhotosUI
import CoreTransferable
import UniformTypeIdentifiers

struct PhotoImportSheet: View {

    enum Mode {
        case newProject
        case existing(Project)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    @State private var viewModel: PhotoImportViewModel
    @State private var selection: [PhotosPickerItem] = []

    private let mode: Mode
    private let maxSelection: Int?
    private let onFinished: (Project) -> Void

    init(
        mode: Mode,
        repository: ProjectRepositoryProtocol,
        maxSelection: Int? = nil,
        onFinished: @escaping (Project) -> Void = { _ in }
    ) {
        self.mode = mode
        self.maxSelection = maxSelection
        self.onFinished = onFinished
        _viewModel = State(initialValue: PhotoImportViewModel(repository: repository))
    }

    private func close() {
        guard let project = viewModel.completedProject else { return }
        onFinished(project)
        dismiss()
    }

    var body: some View {
        NavigationStack {
            content
                .background(theme.canvas)
                .navigationTitle(navigationTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if case .configuring = viewModel.phase {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("İptal") { dismiss() }
                        }
                    }
                }
        }
        .interactiveDismissDisabled(viewModel.phase == .importing)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .configuring: configuring
        case .importing: importing
        case .done(let count): done(count)
        case .failed(let message): failure(message)
        }
    }

    private var configuring: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    picker
                    if case .newProject = mode {
                        titleField
                        categoryRow
                        cadenceRow
                    } else if case .existing(let project) = mode {
                        targetRow(project)
                    }
                }
                .padding(20)
            }
            importButton
        }
    }

    private var picker: some View {
        PhotosPicker(
            selection: $selection,
            maxSelectionCount: maxSelection,
            selectionBehavior: .continuousAndOrdered,
            matching: .images,
            preferredItemEncoding: .current,
            photoLibrary: .shared()
        ) {
            HStack(spacing: 14) {
                Image(systemName: selection.isEmpty ? "photo.stack" : "checkmark.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(theme.accent)
                    .frame(width: 44, height: 44)
                    .background(theme.accent.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(selection.isEmpty ? "Fotoğraf Seç" : "\(selection.count) fotoğraf seçildi")
                        .font(Theme.headline(17)).foregroundStyle(theme.ink)
                    Text(pickerSubtitle)
                        .font(Theme.caption(13)).foregroundStyle(theme.inkMuted)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(theme.inkMuted)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BAŞLIK").font(Theme.caption(12)).foregroundStyle(theme.inkMuted).tracking(1)
            TextField("ör. Tatil", text: $viewModel.title)
                .font(Theme.headline(20))
                .padding(16)
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var categoryRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("KATEGORİ").font(Theme.caption(12)).foregroundStyle(theme.inkMuted).tracking(1)
            HStack {
                Image(systemName: Theme.icon(for: viewModel.category)).foregroundStyle(theme.accent)
                Picker("Kategori", selection: $viewModel.category) {
                    ForEach(ProjectCategory.allCases.filter { !$0.isPro }) { category in
                        Text(category.displayName).tag(category)
                    }
                }
                .tint(theme.ink)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var cadenceRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ÇEKİM SIKLIĞI").font(Theme.caption(12)).foregroundStyle(theme.inkMuted).tracking(1)
            Picker("Sıklık", selection: $viewModel.cadence) {
                ForEach(CaptureCadence.allCases) { cadence in
                    Text(cadence.displayName).tag(cadence)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private func targetRow(_ project: Project) -> some View {
        HStack(spacing: 14) {
            Image(systemName: Theme.icon(for: project.category))
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.accent(for: project.category))
                .frame(width: 44, height: 44)
                .background(Theme.accent(for: project.category).opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("Şuraya eklenecek").font(Theme.caption(12)).foregroundStyle(theme.inkMuted)
                Text(project.title).font(Theme.headline(17)).foregroundStyle(theme.ink)
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var importButton: some View {
        Button(action: startImport) {
            Text(selection.isEmpty ? "Fotoğraf seç" : "\(selection.count) fotoğrafı içe aktar")
                .font(Theme.headline(17))
        }
        .buttonStyle(.timelapsePrimary)
        .disabled(!canImport)
        .padding(20)
    }

    private var pickerSubtitle: LocalizedStringKey {
        if !selection.isEmpty { return "Değiştirmek için dokun" }
        if let maxSelection { return "En fazla \(maxSelection) fotoğraf seçebilirsin (ücretsiz sınır)" }
        return "Kütüphanenden yüzlerce kare seçebilirsin"
    }

    private var canImport: Bool {
        guard !selection.isEmpty else { return false }
        if case .newProject = mode { return viewModel.isValidNewProject }
        return true
    }

    private var importing: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView(value: viewModel.progress)
                .progressViewStyle(.linear)
                .tint(theme.accent)
                .frame(maxWidth: 240)
            Text("İçe aktarılıyor… %\(Int(viewModel.progress * 100))")
                .font(Theme.headline(16)).foregroundStyle(theme.ink)
            Text("Kareler tarihe göre sıralanıyor")
                .font(Theme.caption(13)).foregroundStyle(theme.inkMuted)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private func done(_ count: Int) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(theme.accent)
            Text("\(count) kare eklendi")
                .font(.system(size: 24, weight: .bold)).foregroundStyle(theme.ink)
            Text("Bu projeye çekmeye devam edebilirsin.")
                .font(Theme.caption(14)).foregroundStyle(theme.inkMuted)
                .multilineTextAlignment(.center)
            Spacer()
            Button("Bitti") { close() }
            .buttonStyle(.timelapsePrimary)
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private func failure(_ message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44)).foregroundStyle(theme.inkMuted)
            Text(message)
                .font(Theme.headline(16)).foregroundStyle(theme.ink)
                .multilineTextAlignment(.center)
            Spacer()
            Button("Kapat") { dismiss() }
                .buttonStyle(.timelapsePrimary)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private func startImport() {
        let sources = selection.enumerated().map { index, item in
            PhotoImportSource(
                assetIdentifier: item.itemIdentifier,
                selectionIndex: index,
                load: {
                    if let photo = try? await item.loadTransferable(type: ImportedPhoto.self) {
                        return photo.data
                    }
                    return (try? await item.loadTransferable(type: Data.self)) ?? nil
                }
            )
        }
        Task {
            switch mode {
            case .newProject:
                _ = await viewModel.importIntoNewProject(sources: sources)
            case .existing(let project):
                await viewModel.importInto(project: project, sources: sources)
            }
        }
    }

    private var navigationTitle: String {
        if case .existing = mode { return String(localized: "Fotoğraf Ekle", bundle: .appLanguage) }
        return String(localized: "Fotoğraflardan Oluştur", bundle: .appLanguage)
    }
}

private struct ImportedPhoto: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            ImportedPhoto(data: data)
        }
        FileRepresentation(importedContentType: .image) { received in
            ImportedPhoto(data: try Data(contentsOf: received.file))
        }
    }
}
