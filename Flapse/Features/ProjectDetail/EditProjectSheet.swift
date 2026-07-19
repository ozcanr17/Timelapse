import SwiftUI
import SwiftData

struct EditProjectSheet: View {

    let project: Project

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme

    @State private var title: String
    @State private var category: ProjectCategory
    @State private var cadence: CaptureCadence

    init(project: Project) {
        self.project = project
        _title = State(initialValue: project.title)
        _category = State(initialValue: project.category)
        _cadence = State(initialValue: project.cadence)
    }

    private var sanitizedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("BAŞLIK").font(Theme.caption(12)).foregroundStyle(theme.inkMuted).tracking(1)
                        TextField("ör. Sakal", text: $title)
                            .font(Theme.headline(20))
                            .padding(16)
                            .background(theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("KATEGORİ").font(Theme.caption(12)).foregroundStyle(theme.inkMuted).tracking(1)
                        HStack {
                            Image(systemName: Theme.icon(for: category)).foregroundStyle(theme.accent)
                            Picker("Kategori", selection: $category) {
                                ForEach(ProjectCategory.allCases.filter { !$0.isPro || $0 == project.category }) { option in
                                    Text(option.displayName).tag(option)
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

                    VStack(alignment: .leading, spacing: 8) {
                        Text("ÇEKİM SIKLIĞI").font(Theme.caption(12)).foregroundStyle(theme.inkMuted).tracking(1)
                        Picker("Sıklık", selection: $cadence) {
                            ForEach(CaptureCadence.allCases) { option in
                                Text(option.displayName).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .padding(20)
            }
            .background(theme.canvas)
            .navigationTitle("Projeyi Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }
                        .fontWeight(.bold)
                        .disabled(sanitizedTitle.isEmpty)
                }
            }
        }
    }

    private func save() {
        try? ProjectRepository(context: modelContext).updateProject(
            project,
            title: sanitizedTitle,
            category: category,
            cadence: cadence
        )
        dismiss()
    }
}
