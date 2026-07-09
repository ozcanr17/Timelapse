import AVFoundation
import Foundation
import SwiftData
import UIKit

enum TimelapseLibrary {

    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SavedTimelapses", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    @MainActor
    static func save(videoURL: URL, title: String, context: ModelContext) async throws -> SavedTimelapse {
        let fileName = "\(UUID().uuidString).mp4"
        let destination = directory.appendingPathComponent(fileName)
        try FileManager.default.copyItem(at: videoURL, to: destination)

        let asset = AVURLAsset(url: destination)
        let duration = (try? await asset.load(.duration).seconds) ?? 0
        var posterData: Data?
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 640, height: 640)
        if let cgImage = try? await generator.image(at: .zero).image {
            posterData = UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.8)
        }

        let item = SavedTimelapse(title: title, fileName: fileName, duration: duration, posterData: posterData)
        context.insert(item)
        try context.save()
        return item
    }

    @MainActor
    static func delete(_ item: SavedTimelapse, context: ModelContext) {
        try? FileManager.default.removeItem(at: item.fileURL)
        context.delete(item)
        try? context.save()
    }
}

@MainActor
@Observable
final class TimelapseRenderService {

    static let shared = TimelapseRenderService()

    struct Job: Identifiable {
        let id: UUID
        let title: String
        let startedAt: Date
        let viewModel: TimelapseExportViewModel
    }

    private(set) var jobs: [Job] = []
    private var backgroundTasks: [UUID: UIBackgroundTaskIdentifier] = [:]

    var activeJobs: [Job] {
        jobs.filter { $0.viewModel.phase == .rendering }
    }

    var finishedJobs: [Job] {
        jobs.filter {
            if case .finished = $0.viewModel.phase { return true }
            return false
        }
    }

    func viewModel(for project: Project) -> TimelapseExportViewModel {
        if let job = jobs.first(where: { $0.id == project.id }) { return job.viewModel }
        let job = Job(id: project.id, title: project.title, startedAt: Date.now, viewModel: TimelapseExportViewModel())
        jobs.append(job)
        return job.viewModel
    }

    func didStartRender(for project: Project) {
        let id = project.id
        guard let job = jobs.first(where: { $0.id == id }) else { return }
        if backgroundTasks[id] == nil {
            backgroundTasks[id] = UIApplication.shared.beginBackgroundTask(withName: "timelapse-render") { [weak self] in
                Task { @MainActor in self?.endBackgroundTask(for: id) }
            }
        }
        RenderActivityCenter.start(id: id, title: job.title)
        Task {
            while job.viewModel.phase == .rendering {
                RenderActivityCenter.update(id: id, progress: job.viewModel.progress)
                try? await Task.sleep(for: .seconds(1))
            }
        }
        Task {
            await job.viewModel.waitForRender()
            endBackgroundTask(for: id)
            if case .finished = job.viewModel.phase {
                RenderActivityCenter.finish(id: id, success: true)
            } else {
                RenderActivityCenter.finish(id: id, success: false)
            }
        }
    }

    func cancel(projectID: UUID) {
        guard let job = jobs.first(where: { $0.id == projectID }) else { return }
        job.viewModel.cancel()
        RenderActivityCenter.finish(id: projectID, success: false)
        endBackgroundTask(for: projectID)
    }

    func discard(projectID: UUID) {
        cancel(projectID: projectID)
        jobs.removeAll { $0.id == projectID }
    }

    func saveToLibrary(projectID: UUID, context: ModelContext) async -> SavedTimelapse? {
        guard let job = jobs.first(where: { $0.id == projectID }),
              case .finished(let url) = job.viewModel.phase else { return nil }
        return try? await TimelapseLibrary.save(videoURL: url, title: job.title, context: context)
    }

    private func endBackgroundTask(for id: UUID) {
        if let task = backgroundTasks.removeValue(forKey: id) {
            UIApplication.shared.endBackgroundTask(task)
        }
    }
}
