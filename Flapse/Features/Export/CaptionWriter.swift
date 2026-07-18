import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Cihaz üstü Apple Foundation Models ile paylaşım metni üretir (iOS 26+, uygunsa).
/// Hiçbir veri cihaz dışına çıkmaz.
enum CaptionWriter {

    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return SystemLanguageModel.default.availability == .available
        }
        #endif
        return false
    }

    static func caption(title: String, frames: Int, days: Int) async -> String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            guard SystemLanguageModel.default.availability == .available else { return nil }
            let language = Locale(identifier: AppLanguage.current.localeIdentifier ?? Locale.preferredLanguages.first ?? "en")
                .localizedString(forLanguageCode: AppLanguage.current.localeIdentifier ?? Locale.preferredLanguages.first ?? "en") ?? "English"
            let session = LanguageModelSession()
            let prompt = """
            Write one short, punchy social media caption (max 140 characters, no hashtags, exactly one fitting emoji) in \(language) for a timelapse video that documents "\(title)" through \(frames) photos taken over \(days) days.
            Reply with only the caption text.
            """
            let response = try? await session.respond(to: prompt)
            return response?.content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        #endif
        return nil
    }
}
