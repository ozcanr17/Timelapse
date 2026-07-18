import Foundation
import SwiftData

@Model
final class SavedTimelapse {
    var id: UUID = UUID()
    var title: String = ""
    var createdAt: Date = Date.now
    var fileName: String = ""
    var duration: Double = 0
    var deletedAt: Date? = nil
    @Attribute(.externalStorage) var posterData: Data? = nil

    init(title: String, fileName: String, duration: Double, posterData: Data?) {
        self.id = UUID()
        self.title = title
        self.createdAt = Date.now
        self.fileName = fileName
        self.duration = duration
        self.posterData = posterData
    }

    var fileURL: URL {
        TimelapseLibrary.directory.appendingPathComponent(fileName)
    }
}
