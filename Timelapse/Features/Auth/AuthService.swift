import Foundation
import CryptoKit
import AuthenticationServices

/// Apple ile Giriş akışını ve "admin" tanımını yöneten servis. Kimliği ve e-postayı
/// cihazda saklar; tanınan bir admin e-postasıyla giriş yapılırsa çağıran taraf Pro'yu açar.
@MainActor
@Observable
final class AuthService {

    /// Admin e-posta beyaz listesi — GİZLİLİK için e-postanın düz metni değil, SHA-256
    /// özeti saklanır (bu depo herkese açık). Kendi e-postanın özetini eklemek için:
    ///   printf '%s' 'kendi@epostan.com' | shasum -a 256
    /// çıktısındaki 64 karakterlik hex'i bu kümeye ekle.
    static let adminEmailHashes: Set<String> = [
        "07c71a6a73dc2a6619e400709d1129c4683848947acaa63046be2dcc2d318cd0",
        "047b8cf438383f9b55148f23f24c41e35dedee0aaff95e40756adb17732146c7"
    ]

    private enum Key {
        static let userID = "auth.appleUserID"
        static let email = "auth.email"
        static let name = "auth.name"
        static let adminGrant = "auth.adminGranted"
    }

    init() {
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    private(set) var userID: String? = UserDefaults.standard.string(forKey: Key.userID)
    private(set) var email: String? = UserDefaults.standard.string(forKey: Key.email)
    private(set) var displayName: String? = UserDefaults.standard.string(forKey: Key.name)

    var isSignedIn: Bool { userID != nil }

    /// Saklanan e-posta admin listesinde mi — ya da bu hesaba daha önce (herhangi bir
    /// cihazda) admin yetkisi verilmiş mi? Apple, e-postayı yalnızca İLK yetkilendirmede
    /// ilettiği için yetki bir kez tanındığında iCloud anahtar-değer deposuna yazılır ve
    /// aynı iCloud hesabındaki tüm cihazlarda geçerli kalır.
    var isAdmin: Bool {
        Self.isAdminEmail(email) || Self.storedAdminGrant
    }

    static var storedAdminGrant: Bool {
        NSUbiquitousKeyValueStore.default.bool(forKey: Key.adminGrant)
            || UserDefaults.standard.bool(forKey: Key.adminGrant)
    }

    /// Geliştirici derlemesinden bu iCloud hesabına kalıcı admin yetkisi verir; yetki
    /// iCloud üzerinden tüm cihazlara ve mağaza sürümlerine taşınır.
    static func grantAdminForCurrentICloudAccount() {
        persistAdminGrant()
    }

    private static func persistAdminGrant() {
        UserDefaults.standard.set(true, forKey: Key.adminGrant)
        NSUbiquitousKeyValueStore.default.set(true, forKey: Key.adminGrant)
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    /// Bir e-posta admin mi? Karşılaştırma, düz metin yerine SHA-256 özeti üzerinden yapılır.
    static func isAdminEmail(_ email: String?) -> Bool {
        guard let normalized = email?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
              !normalized.isEmpty else { return false }
        return adminEmailHashes.contains(sha256Hex(normalized))
    }

    /// Bir metnin SHA-256 özetini 64 karakterlik hex olarak döner.
    static func sha256Hex(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// Apple'ın döndürdüğü yetkiyi işler ve kimliği saklar. Admin tanınırsa `true` döner.
    /// (E-posta ve ad Apple tarafından YALNIZCA ilk girişte verilir; geldiğinde saklarız.)
    @discardableResult
    func handle(_ authorization: ASAuthorization) -> Bool {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            return false
        }
        userID = credential.user
        UserDefaults.standard.set(credential.user, forKey: Key.userID)

        if let email = credential.email {
            self.email = email
            UserDefaults.standard.set(email, forKey: Key.email)
        }
        if let full = credential.fullName {
            let name = [full.givenName, full.familyName].compactMap { $0 }.joined(separator: " ")
            if !name.isEmpty {
                displayName = name
                UserDefaults.standard.set(name, forKey: Key.name)
            }
        }
        if isAdmin {
            Self.persistAdminGrant()
        }
        return isAdmin
    }

    func signOut() {
        userID = nil
        email = nil
        displayName = nil
        [Key.userID, Key.email, Key.name].forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }
}
