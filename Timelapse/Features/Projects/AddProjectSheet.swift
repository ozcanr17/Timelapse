import SwiftUI
import SwiftData

/// "Yeni proje" formunu gösteren sheet. İnce bir görünüm: tüm mantık ViewModel'de.
struct AddProjectSheet: View {

    @Environment(\.dismiss) private var dismiss

    // ViewModel'i bu görünüm sahiplenir (@State). Bağımlılığını (repository) init'te
    // enjekte ediyoruz; bu, @State içine bağımlılık geçirmenin standart yoludur.
    @State private var viewModel: AddProjectViewModel

    init(repository: ProjectRepositoryProtocol) {
        _viewModel = State(initialValue: AddProjectViewModel(repository: repository))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Proje") {
                    TextField("Başlık (ör. Sakal)", text: $viewModel.title)

                    Picker("Kategori", selection: $viewModel.category) {
                        ForEach(ProjectCategory.allCases) { category in
                            Text(category.displayName).tag(category)
                        }
                    }

                    Picker("Çekim sıklığı", selection: $viewModel.cadence) {
                        ForEach(CaptureCadence.allCases) { cadence in
                            Text(cadence.displayName).tag(cadence)
                        }
                    }
                }
            }
            .navigationTitle("Yeni Proje")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        if viewModel.save() { dismiss() }
                    }
                    .disabled(!viewModel.isValid)   // geçersizse pasif
                }
            }
            .alert("Hata", isPresented: errorBinding) {
                Button("Tamam", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    // errorMessage opsiyonelini, alert'in beklediği Bool bağına çeviren küçük köprü.
    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in if !isPresented { viewModel.errorMessage = nil } }
        )
    }
}

#Preview {
    AddProjectSheet(
        repository: ProjectRepository(context: AppModelContainer.makeInMemory().mainContext)
    )
}
