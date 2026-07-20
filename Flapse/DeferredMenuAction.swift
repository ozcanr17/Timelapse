import Foundation

@MainActor
enum DeferredMenuAction {
    static func perform(_ action: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            // Context menu kapanışının state değişikliğiyle yarışmaması için iki
            // frame tanı; eski 220 ms gecikme her işlemi hissedilir biçimde yavaştı.
            try? await Task.sleep(for: .milliseconds(32))
            guard !Task.isCancelled else { return }
            action()
        }
    }
}
