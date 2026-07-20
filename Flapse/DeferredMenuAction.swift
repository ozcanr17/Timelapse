import Foundation

@MainActor
enum DeferredMenuAction {
    static func perform(_ action: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled else { return }
            action()
        }
    }
}
