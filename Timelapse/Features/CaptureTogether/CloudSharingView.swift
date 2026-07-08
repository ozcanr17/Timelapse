import SwiftUI
import CloudKit
import UIKit

/// Sistemin "Kişi Ekle / paylaş" ekranını (UICloudSharingController) SwiftUI'da sunar.
struct CloudSharingView: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer
    var onComplete: (CKShare) -> Void = { _ in }

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.delegate = context.coordinator
        controller.availablePermissions = [.allowReadWrite, .allowPrivate]
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(share: share, onComplete: onComplete) }

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        let share: CKShare
        let onComplete: (CKShare) -> Void

        init(share: CKShare, onComplete: @escaping (CKShare) -> Void) {
            self.share = share
            self.onComplete = onComplete
        }

        func itemTitle(for csc: UICloudSharingController) -> String? {
            csc.share?[CKShare.SystemFieldKey.title] as? String
        }

        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {}

        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            onComplete(csc.share ?? share)
        }

        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            onComplete(csc.share ?? share)
        }
    }
}
