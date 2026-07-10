import Photos
import SwiftUI
import UIKit

enum PhotoLibrarySaver {

    enum Outcome {
        case saved
        case denied
        case failed
    }

    static func saveVideo(at url: URL) async -> Outcome {
        await save {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }
    }

    static func saveImage(_ image: UIImage) async -> Outcome {
        await save {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
    }

    private static func save(_ makeRequest: @escaping () -> Void) async -> Outcome {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { return .denied }
        do {
            try await PHPhotoLibrary.shared().performChanges(makeRequest)
            return .saved
        } catch {
            return .failed
        }
    }

    @MainActor
    static func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

extension View {
    func photosDeniedAlert(isPresented: Binding<Bool>) -> some View {
        alert("Fotoğraflara erişim izni yok", isPresented: isPresented) {
            Button("Ayarları Aç") { PhotoLibrarySaver.openSettings() }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Videoyu kaydetmek için Ayarlar'dan Flapse'e Fotoğraflara ekleme izni ver.")
        }
    }
}
