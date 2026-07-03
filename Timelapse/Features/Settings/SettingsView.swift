import SwiftUI
import SwiftData
import UIKit

struct SettingsView: View {

    @Environment(StoreService.self) private var store
    @Environment(\.openURL) private var openURL
    @Environment(\.theme) private var theme
    @Query private var projects: [Project]

    @AppStorage(AppTheme.storageKey) private var themeID = AppTheme.filmNegative.rawValue
    @AppStorage(ReminderScheduler.enabledKey) private var remindersEnabled = false
    @AppStorage(ReminderScheduler.hourKey) private var reminderHour = 19

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
                            .foregroundStyle(theme.ink)
                    } icon: {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(theme.accent)
                    }
                } else {
                    Button {
                        showPaywall = true
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Timelapse Pro'ya Geç")
                                    .font(Theme.headline(15))
                                    .foregroundStyle(theme.ink)
                                Text("Sınırsız proje, 4K filigransız export")
                                    .font(Theme.caption(12))
                                    .foregroundStyle(theme.inkMuted)
                            }
                        } icon: {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(theme.accent)
                        }
                    }
                }
                Button("Satın alımları geri yükle") {
                    Task { await store.restore() }
                }
                .font(Theme.body(15))
                .foregroundStyle(theme.secondary)
            }

            Section("Görünüm") {
                ForEach(AppTheme.allCases) { appTheme in
                    ThemeRow(appTheme: appTheme, isSelected: themeID == appTheme.rawValue) {
                        themeID = appTheme.rawValue
                    }
                }
            }

            Section("Hatırlatıcı") {
                Toggle("Çekim hatırlatıcıları", isOn: $remindersEnabled)
                    .tint(theme.accent)
                if remindersEnabled {
                    Picker("Saat", selection: $reminderHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(String(format: "%02d:00", hour))
                                .font(Theme.stamp(14))
                                .tag(hour)
                        }
                    }
                }
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
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                } label: {
                    LabeledContent("Uygulama dili") {
                        Text(currentLanguageName).font(Theme.caption(13))
                    }
                }
                .foregroundStyle(theme.ink)
                Button("Karşılama ekranını göster") {
                    showWelcome = true
                }
                .foregroundStyle(theme.ink)
                Button("Kamera izni ayarları") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                .foregroundStyle(theme.ink)
            }

            Section {
                VStack(spacing: 10) {
                    LogoMark(size: 56)
                    Text("Timelapse")
                        .font(Theme.headline(17))
                        .foregroundStyle(theme.ink)
                    Text("Sürüm \(appVersion)")
                        .font(Theme.stamp(12, weight: .regular))
                        .foregroundStyle(theme.inkMuted)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.canvas)
        .navigationTitle("Ayarlar")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) {
            PaywallView(store: store)
        }
        .fullScreenCover(isPresented: $showWelcome) {
            WelcomeView { showWelcome = false }
        }
        .onChange(of: remindersEnabled) { _, enabled in
            if enabled {
                Task {
                    let granted = await ReminderScheduler.shared.requestAuthorization()
                    if granted {
                        ReminderScheduler.shared.sync(projects: projects)
                    } else {
                        remindersEnabled = false
                    }
                }
            } else {
                ReminderScheduler.shared.sync(projects: projects)
            }
        }
        .onChange(of: reminderHour) {
            ReminderScheduler.shared.sync(projects: projects)
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private var currentLanguageName: String {
        let code = Locale.current.language.languageCode?.identifier ?? "tr"
        return code == "tr" ? "Türkçe" : "English"
    }
}

private struct ThemeRow: View {
    let appTheme: AppTheme
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(appTheme.palette.canvas)
                        .overlay(Circle().strokeBorder(theme.inkMuted.opacity(0.25), lineWidth: 1))
                        .frame(width: 30, height: 30)
                    Circle()
                        .fill(appTheme.palette.accent)
                        .frame(width: 16, height: 16)
                        .offset(x: 5, y: 5)
                    Circle()
                        .fill(appTheme.palette.secondary)
                        .frame(width: 9, height: 9)
                        .offset(x: -6, y: -5)
                }

                Text(appTheme.displayName)
                    .font(Theme.body(15))
                    .foregroundStyle(theme.ink)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(theme.accent)
                }
            }
        }
        .accessibilityIdentifier("theme-\(appTheme.rawValue)")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(AppModelContainer.makeInMemory())
    .environment(StoreService())
}
