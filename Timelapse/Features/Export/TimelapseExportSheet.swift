import SwiftUI
import SwiftData
import AVKit

struct TimelapseExportSheet: View {

    let project: Project

    @Environment(StoreService.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = TimelapseExportViewModel()
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.canvas.ignoresSafeArea()
                content
            }
            .navigationTitle("Timelapse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
            .task { await export() }
            .sheet(isPresented: $showPaywall) {
                PaywallView(store: store)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .idle, .rendering:
            renderingView
        case .finished(let url):
            finishedView(url)
        case .failed(let message):
            failedView(message)
        }
    }

    private var renderingView: some View {
        VStack(spacing: 24) {
            LogoMark(size: 72)
            VStack(spacing: 8) {
                Text("Kareler birleştiriliyor…")
                    .font(Theme.headline(17))
                    .foregroundStyle(Theme.ink)
                Text(viewModel.progress, format: .percent.precision(.fractionLength(0)))
                    .font(Theme.stamp(15))
                    .foregroundStyle(Theme.inkMuted)
            }
            ProgressView(value: viewModel.progress)
                .tint(Theme.rust)
                .padding(.horizontal, 48)
        }
    }

    private func finishedView(_ url: URL) -> some View {
        VStack(spacing: 20) {
            VideoPlayer(player: AVPlayer(url: url))
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
                .frame(maxHeight: 460)

            ShareLink(item: url) {
                Label("Videoyu Paylaş", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.timelapsePrimary)

            if !store.isPro {
                Button {
                    showPaywall = true
                } label: {
                    Text("Filigranı kaldır, 4K'ya geç — Pro")
                        .font(Theme.caption(13))
                        .foregroundStyle(Theme.teal)
                }
            }
        }
        .padding(20)
    }

    private func failedView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(Theme.rust)
            Text(message)
                .font(Theme.body(15))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Button("Tekrar dene") {
                Task { await export() }
            }
            .buttonStyle(.timelapsePrimary)
            .frame(width: 200)
        }
        .padding(24)
    }

    private func export() async {
        await viewModel.export(
            frames: project.sortedEntries.compactMap(\.imageData),
            isPro: store.isPro
        )
    }
}

#Preview {
    let container = AppModelContainer.makeInMemory()
    let project = Project(title: "Sakal", category: .hairAndBeard, cadence: .daily)
    container.mainContext.insert(project)
    return TimelapseExportSheet(project: project)
        .modelContainer(container)
        .environment(StoreService())
}
