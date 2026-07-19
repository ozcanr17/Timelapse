import UIKit
import CloudKit

/// Bir "Birlikte Çekim" davet bağlantısı açıldığında CloudKit paylaşımını hesaba ekler.
final class FlapseAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        FlapseSceneDelegate.acceptShare(cloudKitShareMetadata)
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = FlapseSceneDelegate.self
        return configuration
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard CKNotification(fromRemoteNotificationDictionary: userInfo) != nil else {
            completionHandler(.noData)
            return
        }
        NotificationCenter.default.post(name: .flapseCloudKitChanged, object: nil)
        completionHandler(.newData)
    }
}

final class FlapseSceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        Self.acceptShare(cloudKitShareMetadata)
    }

    static func acceptShare(_ metadata: CKShare.Metadata) {
        Task { @MainActor in
            try? await SharedProjectService.shared.accept(metadata)
            NotificationCenter.default.post(name: .flapseDidAcceptShare, object: metadata)
        }
    }
}

extension Notification.Name {
    static let flapseDidAcceptShare = Notification.Name("flapseDidAcceptShare")
    static let flapseCloudKitChanged = Notification.Name("flapseCloudKitChanged")
    static let flapseMilestone = Notification.Name("flapseMilestone")
}
