import SwiftUI

/// Premium aboneliği tanıtan ve satın almayı sunan paywall ekranı.
struct PaywallView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: PaywallViewModel

    init(store: StoreServiceProtocol) {
        _viewModel = State(initialValue: PaywallViewModel(store: store))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    featureList
                    packageButtons
                    restoreButton
                    legalText
                }
                .padding()
            }
            .navigationTitle("Timelapse Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
            .task { await viewModel.load() }
            .alert("Hata", isPresented: errorBinding) {
                Button("Tamam", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "crown.fill")
                .font(.largeTitle)
                .foregroundStyle(.yellow)
            Text("Tüm özelliklerin kilidini aç")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
        }
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProFeatureRow(icon: "infinity", text: "Sınırsız proje")
            ProFeatureRow(icon: "wand.and.stars", text: "Akıllı hizalama")
            ProFeatureRow(icon: "icloud.fill", text: "iCloud yedekleme")
            ProFeatureRow(icon: "person.2.fill", text: "Çift (couple) modu")
            ProFeatureRow(icon: "film", text: "Filigransız 4K export")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var packageButtons: some View {
        VStack(spacing: 12) {
            if viewModel.packages.isEmpty {
                ProgressView()
                    .padding()
            } else {
                ForEach(viewModel.packages) { package in
                    Button {
                        Task {
                            if await viewModel.purchase(package) { dismiss() }
                        }
                    } label: {
                        HStack {
                            Text(package.displayName)
                            Spacer()
                            Text(package.displayPrice).bold()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isPurchasing)
                }
            }
        }
    }

    private var restoreButton: some View {
        Button("Satın alımları geri yükle") {
            Task {
                await viewModel.restore()
                if viewModel.isPro { dismiss() }
            }
        }
        .font(.footnote)
        .disabled(viewModel.isPurchasing)
    }

    private var legalText: some View {
        Text("Abonelik otomatik yenilenir; istediğin zaman Ayarlar’dan iptal edebilirsin.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

private struct ProFeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.tint)
                .frame(width: 28)
            Text(text)
            Spacer()
        }
    }
}

#Preview {
    // Not: gerçek paketler .storekit yapılandırmasıyla dolar; önizlemede liste boş görünebilir.
    PaywallView(store: StoreService())
}
