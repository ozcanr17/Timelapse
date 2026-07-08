import SwiftUI
import SwiftData
import UIKit
import AuthenticationServices

struct SettingsView: View {

    @Environment(StoreService.self) private var store
    @Environment(\.openURL) private var openURL
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Query private var projects: [Project]

    @AppStorage(AppTheme.storageKey) private var themeID = AppTheme.filmNegative.rawValue
    @AppStorage(AppLanguage.storageKey) private var languageID = AppLanguage.system.rawValue
    @AppStorage(ReminderScheduler.enabledKey) private var remindersEnabled = false
    @AppStorage(ReminderScheduler.hourKey) private var reminderHour = 19
    @AppStorage(PremiumFeature.smartAlignment.preferenceKey!) private var smartAlignmentEnabled = false
    @AppStorage(PremiumFeature.cloudBackup.preferenceKey!) private var cloudBackupEnabled = false

    @State private var auth = AuthService()
    @State private var showPaywall = false
    @State private var showWelcome = false
    @State private var devTapCount = 0
    @State private var adminSignInMessage: String?

    private var totalEntries: Int {
        projects.reduce(0) { $0 + ($1.entries?.count ?? 0) }
    }

    var body: some View {
        List {
            Section("Üyelik") {
                if store.isPro {
                    Label {
                        Text("Flapse Pro aktif")
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
                                Text("Flapse Pro'ya Geç")
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

            Section {
                accountContent
            } header: {
                Text("Hesap")
            } footer: {
                if let adminSignInMessage {
                    Text(adminSignInMessage)
                        .foregroundStyle(theme.accent)
                }
            }

            Section {
                ProToggleRow(
                    feature: .smartAlignment,
                    isOn: $smartAlignmentEnabled,
                    isPro: store.isPro
                ) { showPaywall = true }
                ProToggleRow(
                    feature: .cloudBackup,
                    isOn: $cloudBackupEnabled,
                    isPro: store.isPro
                ) { showPaywall = true }
                if store.isPro, cloudBackupEnabled {
                    Label {
                        Text(iCloudActive
                             ? "iCloud yedekleme etkin."
                             : "iCloud isteği kaydedildi; şu an yerel depoya düşülüyor (ücretli Apple hesabı gerekir).")
                            .font(Theme.caption(12))
                            .foregroundStyle(theme.inkMuted)
                    } icon: {
                        Image(systemName: iCloudActive ? "checkmark.icloud.fill" : "icloud.slash")
                            .foregroundStyle(iCloudActive ? theme.accent : theme.inkMuted)
                    }
                }
            } header: {
                Text("Pro Özellikler")
            } footer: {
                if store.isPro {
                    Text("Çift modu (birlikte çekim) her projede sağ üstteki davet düğmesiyle açılır. iCloud değişikliği uygulama yeniden başlatılınca geçerli olur.")
                } else {
                    Text("Bu özellikler Flapse Pro ile açılır.")
                }
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
                                .font(Theme.body(15)).monospacedDigit()
                                .tag(hour)
                        }
                    }
                }
            }

            Section("İstatistik") {
                LabeledContent("Proje") {
                    Text("\(projects.count)").font(Theme.body(15)).monospacedDigit()
                }
                LabeledContent("Toplam çekim") {
                    Text("\(totalEntries)").font(Theme.body(15)).monospacedDigit()
                }
            }

            Section("Uygulama") {
                Picker(selection: languageBinding) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.nativeName).tag(language.rawValue)
                    }
                } label: {
                    Label {
                        Text("Uygulama dili").foregroundStyle(theme.ink)
                    } icon: {
                        Image(systemName: "globe").foregroundStyle(theme.accent)
                    }
                }
                .pickerStyle(.menu)
                .tint(theme.inkMuted)
                NavigationLink {
                    RecentlyDeletedView()
                } label: {
                    Label {
                        Text("Son Silinenler").foregroundStyle(theme.ink)
                    } icon: {
                        Image(systemName: "trash").foregroundStyle(theme.accent)
                    }
                }
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

            #if DEBUG
            if isDeveloperUnlocked {
                Section {
                    Toggle(isOn: developerProBinding) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Pro'yu Test Et (ödeme yok)")
                                    .font(Theme.headline(15))
                                    .foregroundStyle(theme.ink)
                                Text("Tüm Pro özelliklerini satın almadan aç")
                                    .font(Theme.caption(12))
                                    .foregroundStyle(theme.inkMuted)
                            }
                        } icon: {
                            Image(systemName: "ladybug.fill")
                                .foregroundStyle(theme.accent)
                        }
                    }
                    .tint(theme.accent)
                } header: {
                    Text("Geliştirici")
                } footer: {
                    Text("Yalnızca DEBUG derlemesinde görünen test arka kapısı.")
                }
            }
            #endif

            Section {
                VStack(spacing: 10) {
                    LogoMark(size: 56)
                    Text("Flapse")
                        .font(Theme.headline(17))
                        .foregroundStyle(theme.ink)
                    Text("Sürüm \(appVersion)")
                        .font(Theme.caption(12))
                        .foregroundStyle(theme.inkMuted)
                        .contentShape(Rectangle())
                        .onTapGesture { revealDeveloperIfNeeded() }
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

    @ViewBuilder
    private var accountContent: some View {
        if auth.isSignedIn {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(auth.displayName ?? auth.email ?? String(localized: "Apple ID ile girildi", bundle: .appLanguage))
                        .font(Theme.headline(15))
                        .foregroundStyle(theme.ink)
                    if let email = auth.email {
                        Text(email)
                            .font(Theme.caption(12))
                            .foregroundStyle(theme.inkMuted)
                    }
                    if auth.isAdmin {
                        Text("Admin — Pro etkin")
                            .font(Theme.caption(12))
                            .foregroundStyle(theme.accent)
                    }
                }
            } icon: {
                Image(systemName: "apple.logo")
                    .foregroundStyle(theme.ink)
            }
            Button("Çıkış yap") {
                auth.signOut()
                store.setAdminUnlocked(false)
                adminSignInMessage = nil
            }
            .font(Theme.body(15))
            .foregroundStyle(theme.secondary)
        } else {
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                handleSignIn(result)
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 46)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
    }

    private func handleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if auth.handle(authorization) {
                store.setAdminUnlocked(true)
                adminSignInMessage = String(localized: "Admin olarak giriş yapıldı — Pro açıldı. 👑", bundle: .appLanguage)
            } else {
                adminSignInMessage = String(localized: "Giriş yapıldı. Bu hesap admin değil; Pro açılmadı.", bundle: .appLanguage)
            }
        case .failure:
            adminSignInMessage = String(localized: "Apple ile giriş şu an kullanılamıyor (ücretli Apple Developer hesabı gerekir). Test için sürüm numarasına 7 kez dokunup geliştirici arka kapısını kullan.", bundle: .appLanguage)
        }
    }

    #if DEBUG
    private var isDeveloperUnlocked: Bool {
        devTapCount >= 7 || store.debugUnlocked
    }

    private var developerProBinding: Binding<Bool> {
        Binding(
            get: { store.debugUnlocked },
            set: { store.setDebugUnlocked($0) }
        )
    }
    #endif

    private func revealDeveloperIfNeeded() {
        #if DEBUG
        guard devTapCount < 7 else { return }
        devTapCount += 1
        if devTapCount >= 7 {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        #endif
    }

    private var iCloudActive: Bool {
        UserDefaults.standard.bool(forKey: AppModelContainer.iCloudBackupActiveKey)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private var languageBinding: Binding<String> {
        Binding(
            get: { languageID },
            set: { newValue in
                LanguageOverrideBundle.apply(AppLanguage(rawValue: newValue) ?? .system)
                languageID = newValue
            }
        )
    }
}

/// Pro'ya bağlı bir özelliğin ayarlar satırı. Pro kullanıcıda gerçek bir anahtar (toggle),
/// ücretsiz kullanıcıda ise pasif (inactive) görünen, dokununca paywall açan kilitli satır.
private struct ProToggleRow: View {
    let feature: PremiumFeature
    @Binding var isOn: Bool
    let isPro: Bool
    let onLockedTap: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        if isPro {
            Toggle(isOn: $isOn) { label }
                .tint(theme.accent)
        } else {
            Button(action: onLockedTap) {
                HStack {
                    label
                    Spacer()
                    proBadge
                }
            }
        }
    }

    private var label: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .font(Theme.headline(15))
                    .foregroundStyle(isPro ? theme.ink : theme.inkMuted)
                Text(feature.subtitle)
                    .font(Theme.caption(12))
                    .foregroundStyle(theme.inkMuted)
            }
        } icon: {
            Image(systemName: isPro ? feature.iconName : "lock.fill")
                .foregroundStyle(isPro ? theme.accent : theme.inkMuted)
        }
    }

    private var proBadge: some View {
        Text("PRO")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(theme.accent)
            .clipShape(Capsule())
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
