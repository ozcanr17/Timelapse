import SwiftUI
import SwiftData

/// "Yeni proje" formu. Kategori seçimini varsayılan Picker yerine ikonlu, renkli çip
/// kartları olarak sunuyoruz — AddProjectViewModel'daki mantık hiç değişmedi, sadece
/// bu görünüm katmanı yenilendi (MVVM ayrımının kanıtı: testler değişmeden geçiyor).
struct AddProjectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @Environment(StoreService.self) private var store
    @State private var viewModel: AddProjectViewModel
    @State private var showPaywall = false

    var onCreated: ((Project) -> Void)? = nil

    init(
        repository: ProjectRepositoryProtocol,
        suggestedCategory: ProjectCategory? = nil,
        onCreated: ((Project) -> Void)? = nil
    ) {
        self.onCreated = onCreated
        let viewModel = AddProjectViewModel(repository: repository)
        if let suggestedCategory, !suggestedCategory.isPro {
            viewModel.category = suggestedCategory
        }
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    titleField
                    categoryPicker
                    cadencePicker
                }
                .padding(20)
            }
            .background(theme.canvas)
            .navigationTitle("Yeni Proje")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { if let project = viewModel.save() { dismiss(); onCreated?(project) } }
                        .disabled(!viewModel.isValid)
                        .fontWeight(.bold)
                }
            }
            .alert("Hata", isPresented: errorBinding) {
                Button("Tamam", role: .cancel) {}
            } message: { Text(viewModel.errorMessage ?? "") }
            .sheet(isPresented: $showPaywall) {
                PaywallView(store: store)
            }
        }
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BAŞLIK").font(Theme.caption(12)).foregroundStyle(theme.inkMuted).tracking(1)
            TextField("ör. Sakal", text: $viewModel.title)
                .font(Theme.headline(20))
                .padding(16)
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("KATEGORİ").font(Theme.caption(12)).foregroundStyle(theme.inkMuted).tracking(1)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
                ForEach(ProjectCategory.allCases) { category in
                    let locked = category.isPro && !store.isPro
                    CategoryChip(
                        category: category,
                        isSelected: viewModel.category == category,
                        isLocked: locked
                    ) {
                        if locked {
                            showPaywall = true
                        } else {
                            viewModel.category = category
                        }
                    }
                }
            }
        }
    }

    private var cadencePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ÇEKİM SIKLIĞI").font(Theme.caption(12)).foregroundStyle(theme.inkMuted).tracking(1)
            HStack(spacing: 10) {
                ForEach(CaptureCadence.allCases) { cadence in
                    CadenceChip(cadence: cadence, isSelected: viewModel.cadence == cadence) {
                        viewModel.cadence = cadence
                    }
                }
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })
    }
}

private struct CategoryChip: View {
    let category: ProjectCategory
    let isSelected: Bool
    var isLocked: Bool = false
    let action: () -> Void

    @Environment(\.theme) private var theme

    private var accent: Color { Theme.accent(for: category) }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: Theme.icon(for: category))
                    .font(.system(size: 18, weight: .semibold))
                Text(category.displayName)
                    .font(Theme.caption(12))
            }
            .foregroundStyle(isSelected ? .white : theme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isSelected ? accent : theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(accent, in: Circle())
                        .padding(6)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct CadenceChip: View {
    let cadence: CaptureCadence
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            Text(cadence.displayName)
                .font(Theme.caption(13))
                .foregroundStyle(isSelected ? .white : theme.ink)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(isSelected ? theme.accent : theme.surface)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AddProjectSheet(repository: ProjectRepository(context: AppModelContainer.makeInMemory().mainContext))
        .environment(StoreService())
}
