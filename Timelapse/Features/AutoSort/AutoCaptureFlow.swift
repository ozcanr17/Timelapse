import SwiftUI
import SwiftData
import UIKit

struct AutoCaptureFlow: View {

    let projects: [Project]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    @State private var phase: Phase = .capturing
    @State private var lastData: Data?
    @State private var signature: SubjectSignature = .empty
    @State private var isCreatingProject = false

    private let classifier: SubjectClassifying = SubjectClassifier()
    @State private var locationService = LocationService()

    enum Phase: Equatable {
        case capturing
        case reviewing
        case classifying
        case confirming(UUID)
        case choosing(UUID?)
        case assigned(String)
    }

    var body: some View {
        ZStack {
            CameraCaptureView(onAutoCaptured: handleCaptured)

            switch phase {
            case .reviewing:
                reviewOverlay
            case .classifying:
                classifyingOverlay
            case .confirming(let id):
                if let project = projects.first(where: { $0.id == id }) {
                    confirmationOverlay(project)
                }
            case .assigned(let title):
                assignedOverlay(title)
            default:
                EmptyView()
            }
        }
        .sheet(isPresented: choosingBinding) {
            AutoSortChoiceSheet(
                projects: projects,
                suggestedID: suggestedID,
                subjectLabel: subjectLabel,
                onSelect: assign(to:),
                onCreate: {
                    withAnimation { phase = .capturing }
                    Task {
                        try? await Task.sleep(for: .milliseconds(500))
                        isCreatingProject = true
                    }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isCreatingProject) {
            AddProjectSheet(
                repository: ProjectRepository(context: modelContext),
                suggestedCategory: signature.kind.suggestedCategory
            ) { project in
                assign(to: project)
            }
        }
    }

    private var reviewOverlay: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            VStack(spacing: 20) {
                if let data = lastData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .frame(maxHeight: 460)
                        .shadow(color: .black.opacity(0.4), radius: 18, y: 8)
                }
                Text("Bu kare kullanılsın mı?")
                    .font(Theme.headline(18))
                    .foregroundStyle(.white)
                VStack(spacing: 10) {
                    Button {
                        chooseProject()
                    } label: {
                        Label("Kullan", systemImage: "checkmark")
                            .font(Theme.headline(16))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .foregroundStyle(.black)
                    }
                    .accessibilityIdentifier("usePhotoButton")
                    Button {
                        lastData = nil
                        withAnimation { phase = .capturing }
                    } label: {
                        Label("Tekrar Çek", systemImage: "arrow.counterclockwise")
                            .font(Theme.headline(15))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .foregroundStyle(.white)
                    }
                    .accessibilityIdentifier("retakePhotoButton")
                    Button {
                        dismiss()
                    } label: {
                        Text("Vazgeç")
                            .font(Theme.headline(15))
                            .foregroundStyle(.white.opacity(0.75))
                            .padding(.vertical, 8)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 380)
        }
        .transition(.opacity)
    }

    private var classifyingOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView().tint(.white).controlSize(.large)
                Text("Kare tanınıyor…").font(Theme.headline(16)).foregroundStyle(.white)
            }
        }
        .transition(.opacity)
    }

    private func confirmationOverlay(_ project: Project) -> some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 18) {
                if let data = lastData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: .black.opacity(0.35), radius: 12, y: 5)
                }
                Image(systemName: Theme.icon(for: project.category))
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.white)
                Text("\"\(project.title)\" projesine eklensin mi?")
                    .font(Theme.headline(19)).foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                VStack(spacing: 10) {
                    Button {
                        assign(to: project)
                    } label: {
                        Text("Evet, ekle")
                            .font(Theme.headline(16))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .foregroundStyle(.black)
                    }
                    Button {
                        withAnimation { phase = .choosing(project.id) }
                    } label: {
                        Text("Başka proje seç")
                            .font(Theme.headline(15))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .foregroundStyle(.white)
                    }
                    HStack(spacing: 22) {
                        Button {
                            lastData = nil
                            withAnimation { phase = .capturing }
                        } label: {
                            Label("Tekrar Çek", systemImage: "arrow.counterclockwise")
                                .font(Theme.headline(14))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                        Button {
                            dismiss()
                        } label: {
                            Text("Vazgeç")
                                .font(Theme.headline(14))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(28)
            .frame(maxWidth: 340)
        }
        .transition(.opacity)
    }

    private func assignedOverlay(_ title: String) -> some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 52)).foregroundStyle(.white)
                Text("\(title) projesine eklendi")
                    .font(Theme.headline(18)).foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(28)
        }
        .transition(.opacity)
    }

    private var choosingBinding: Binding<Bool> {
        Binding(
            get: { if case .choosing = phase { true } else { false } },
            set: { newValue in
                if !newValue, case .choosing = phase { dismiss() }
            }
        )
    }

    private var suggestedID: UUID? {
        if case .choosing(let id) = phase { return id }
        return nil
    }

    private var subjectLabel: String? {
        signature.labels.first.map(Self.prettify)
    }

    private func handleCaptured(_ data: Data) {
        lastData = data
        withAnimation { phase = .classifying }
        Task {
            await migrateSignaturesIfNeeded()
            let computed = await classifier.signature(for: data)
            signature = computed
            let sets = projects.compactMap(signatureSet(for:))
            switch ProjectMatcher.decide(for: computed, among: sets) {
            case .autoAssign(let id), .suggest(let id):
                if projects.contains(where: { $0.id == id }) {
                    withAnimation { phase = .confirming(id) }
                } else {
                    withAnimation { phase = .reviewing }
                }
            case .chooseManually:
                withAnimation { phase = .reviewing }
            }
        }
    }

    private func chooseProject() {
        withAnimation { phase = .choosing(nil) }
    }

    private func assign(to project: Project) {
        guard let data = lastData else { return }
        let repository = ProjectRepository(context: modelContext)
        let entry = Entry(
            imageData: data,
            subjectKindRaw: signature.kind == .unknown ? nil : signature.kind.rawValue,
            featurePrintData: signature.isEmpty ? nil : FeatureVector.data(from: signature.vector)
        )
        try? repository.addEntry(entry, to: project)
        Task {
            if let resolved = await locationService.currentLocation() {
                entry.latitude = resolved.latitude
                entry.longitude = resolved.longitude
                entry.placeName = resolved.placeName
                try? repository.saveIfNeeded()
            }
        }
        withAnimation { phase = .assigned(project.title) }
        Task {
            try? await Task.sleep(for: .seconds(1.3))
            dismiss()
        }
    }

    private static let signatureVersionKey = "autosort.signature.version"

    /// Yüz-odaklı imza (v2) öncesinde kaydedilmiş tüm-sahne imzalarını, projelerin son
    /// karelerinden bir kez yeniden hesaplar; eski projeler de yeni eşleştirmeden yararlanır.
    private func migrateSignaturesIfNeeded() async {
        let defaults = UserDefaults.standard
        guard defaults.integer(forKey: Self.signatureVersionKey) < 2 else { return }
        for project in projects {
            for entry in project.sortedEntries.suffix(8) {
                guard let data = entry.imageData else { continue }
                let sig = await classifier.signature(for: data)
                guard !sig.isEmpty else { continue }
                entry.featurePrintData = FeatureVector.data(from: sig.vector)
                if sig.kind != .unknown { entry.subjectKindRaw = sig.kind.rawValue }
            }
        }
        try? modelContext.save()
        defaults.set(2, forKey: Self.signatureVersionKey)
    }

    private func signatureSet(for project: Project) -> ProjectSignatureSet? {
        let entries = project.entries ?? []
        let vectors = entries.compactMap { entry -> [Float]? in
            guard let data = entry.featurePrintData else { return nil }
            let vector = FeatureVector.vector(from: data)
            return vector.isEmpty ? nil : vector
        }
        guard !vectors.isEmpty else { return nil }
        let kinds = entries.compactMap { $0.subjectKindRaw }.compactMap(SubjectKind.init(rawValue:))
        return ProjectSignatureSet(projectID: project.id, kind: Self.mostCommon(kinds) ?? .unknown, vectors: vectors)
    }

    private static func mostCommon(_ kinds: [SubjectKind]) -> SubjectKind? {
        guard !kinds.isEmpty else { return nil }
        var counts: [SubjectKind: Int] = [:]
        for kind in kinds { counts[kind, default: 0] += 1 }
        return counts.max { $0.value < $1.value }?.key
    }

    private static func prettify(_ label: String) -> String {
        label.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

private struct AutoSortChoiceSheet: View {

    let projects: [Project]
    let suggestedID: UUID?
    let subjectLabel: String?
    let onSelect: (Project) -> Void
    let onCreate: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    private var ordered: [Project] {
        guard let suggestedID, let index = projects.firstIndex(where: { $0.id == suggestedID }) else {
            return projects
        }
        var copy = projects
        copy.insert(copy.remove(at: index), at: 0)
        return copy
    }

    var body: some View {
        NavigationStack {
            List {
                if let subjectLabel {
                    Text("Bu karede: \(subjectLabel)")
                        .font(Theme.caption(13)).foregroundStyle(theme.inkMuted)
                        .listRowBackground(Color.clear)
                }
                ForEach(ordered) { project in
                    Button {
                        onSelect(project)
                        dismiss()
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: Theme.icon(for: project.category))
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Theme.accent(for: project.category))
                                .frame(width: 44, height: 44)
                                .background(Theme.accent(for: project.category).opacity(0.15), in: Circle())
                            Text(project.title).font(Theme.headline(16)).foregroundStyle(theme.ink)
                            Spacer()
                            if project.id == suggestedID {
                                Text("Öneri")
                                    .font(Theme.caption(11)).foregroundStyle(.white)
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(theme.accent, in: Capsule())
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(theme.surface)
                }
                Button {
                    onCreate()
                    dismiss()
                } label: {
                    Label("Yeni proje oluştur", systemImage: "plus.circle.fill")
                        .font(Theme.headline(16)).foregroundStyle(theme.accent)
                }
                .listRowBackground(theme.surface)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(theme.canvas)
            .navigationTitle("Hangi projeye?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
            }
        }
    }
}
