import Foundation
import LocalAuthentication

enum DeviceOwnerAuthentication {
    static func authenticate() async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = String(localized: "Vazgeç", bundle: .appLanguage)
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return false }
        return (try? await context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: String(localized: "Face ID veya cihaz parolanla aç.", bundle: .appLanguage)
        )) == true
    }
}
