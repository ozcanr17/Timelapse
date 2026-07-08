import UIKit
import CloudKit

/// Bir "Birlikte Çekim" davet bağlantısı açıldığında CloudKit paylaşımını hesaba ekler.
final class FlapseAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        Task { @MainActor in
            try? await SharedProjectService.shared.accept(cloudKitShareMetadata)
            NotificationCenter.default.post(name: .flapseDidAcceptShare, object: cloudKitShareMetadata)
        }
    }
}

extension Notification.Name {
    static let flapseDidAcceptShare = Notification.Name("flapseDidAcceptShare")
}
