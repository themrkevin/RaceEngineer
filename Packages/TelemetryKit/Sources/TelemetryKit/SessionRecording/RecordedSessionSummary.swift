import Foundation

public struct RecordedSessionSummary: Identifiable, Hashable, Sendable {
    public var id: String { fileURL.path }
    public let fileURL: URL
    public let fileName: String
    public let creationDate: Date
    public let byteSize: Int64
    public let totalFrames: Int
    public let duration: TimeInterval

    public init(fileURL: URL) {
        self.fileURL = fileURL
        self.fileName = fileURL.lastPathComponent

        let attributes = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)) ?? [:]
        self.creationDate = attributes[.creationDate] as? Date ?? Date()
        
        let size = attributes[.size] as? Int64 ?? 0
        self.byteSize = size

        // Binary Layout: 16-byte header + (368 bytes * frameCount)
        let frames = max(0, Int((size - 16) / 368))
        self.totalFrames = frames
        self.duration = Double(frames) / 60.0 // 60Hz standard cadence
    }

    public var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    public var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: byteSize)
    }
}