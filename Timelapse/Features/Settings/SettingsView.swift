import SwiftUI
import SwiftData
import UIKit

struct SettingsView: View {

    @Environment(StoreService.self) private var store
    @Environment(\.openURL) private var openURL
    @Query private var projects: [Project]

    @State private var showPaywall = false
    @State private var showWelcome = false

    private var totalEntries: Int {
        projects.reduce(0) { $0 + ($1.entries?.count ?? 0) }
    }

    var body: some View {
        List {
            Section("Üyelik") {
                if store.isPro {
                    Label {
                        Text("Timelapse Pro aktif")
                            .font(Theme.headline(15))
                            .foregroundStyle(Theme.ink)
                    } icon: {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(Theme.rust)
                    }
                } else {
                    Button {
                        showPaywall = true
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Timelapse Pro'ya Geç")
                                    .font(Theme.headline(15))
                                    .foregroundStyle(Theme.ink)
                                Text("Sınırsız proje, 4K filigransız export")
                                    .font(Theme.caption(12))
                                    .foregroundStyle(Theme.inkMuted)
                            }
                        } icon: {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(Theme.rust)
                        }
                    }
                }
                Button("Satın alımları geri yükle") {
                    Task { await store.restore() }
                }
                .font(Theme.body(15))
                .foregroundStyle(Theme.teal)
            }

            Section("İstatistik") {
                LabeledContent("Proje") {
                    Text("\(projects.count)").font(Theme.stamp(15))
                }
                LabeledContent("Toplam çekim") {
                    Text("\(totalEntries)").font(Theme.stamp(15))
                }
            }

            Section("Uygulama") {
                Button("Karşılama ekranını göster") {
                    showWelcome = true
                }
                .foregroundStyle(Theme.ink)
                Button("Kamera izni ayarları") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                .foregroundStyle(Theme.ink)
            }

            Section {
                VStack(spacing: 10) {
                    LogoMark(size: 56)
                    Text("Timelapse")
                        .font(Theme.headline(17))
                        .foregroundStyle(Theme.ink)
                    Text("Sürüm \(appVersion)")
                        .font(Theme.stamp(12, weight: .regular))
                        .foregroundStyle(Theme.inkMuted)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.canvas)
        .navigationTitle("Ayarlar")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) {
            PaywallView(store: store)
        }
        .fullScreenCover(isPresented: $showWelcome) {
            WelcomeView { showWelcome = false }
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(AppModelContainer.makeInMemory())
    .environment(StoreService())
}
