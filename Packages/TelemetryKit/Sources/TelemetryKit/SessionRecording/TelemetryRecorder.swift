import Foundation
import OSLog

/// Writes decrypted GT7 Packet C telemetry frames to a compact binary file (.race / .bin).
public actor TelemetryRecorder {
    private let logger = Logger(subsystem: "com.raceengineer", category: "TelemetryRecorder")
    private var fileHandle: FileHandle?
    private var isRecording = false
    private var framesRecorded = 0

    public init() {}

    /// Starts recording session frames to the specified file URL.
    public func startRecording(to fileURL: URL) throws {
        guard !isRecording else { return }

        // Create empty file
        FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: fileURL)

        // 16-Byte Header Layout:
        // [0..3]: Magic "RACE" (0x52414345)
        // [4..5]: Version (UInt16 = 1)
        // [6..7]: Packet Size (UInt16 = 368)
        // [8..9]: Sample Rate Hz (UInt16 = 60)
        // [10..15]: Reserved (6 zero-padded bytes)
        var header = Data(capacity: 16)
        var magic: UInt32 = 0x52414345
        var version: UInt16 = 1
        var packetSize: UInt16 = 368
        var sampleRate: UInt16 = 60
        var reserved: UInt64 = 0

        header.append(Data(bytes: &magic, count: 4))
        header.append(Data(bytes: &version, count: 2))
        header.append(Data(bytes: &packetSize, count: 2))
        header.append(Data(bytes: &sampleRate, count: 2))
        header.append(Data(bytes: &reserved, count: 6))

        try handle.write(contentsOf: header)

        self.fileHandle = handle
        self.isRecording = true
        self.framesRecorded = 0

        logger.info("🔴 Session recording started: \(fileURL.lastPathComponent)")
    }

    /// Appends a single decrypted 368-byte frame to disk.
    public func recordFrame(_ decryptedData: Data) {
        guard isRecording, let fileHandle, decryptedData.count >= 368 else { return }
        do {
            try fileHandle.write(contentsOf: decryptedData.prefix(368))
            framesRecorded += 1
        } catch {
            logger.error("❌ Failed writing frame to disk: \(error.localizedDescription)")
        }
    }

    /// Flushes and closes the active file handle.
    public func stopRecording() {
        guard isRecording else { return }
        try? fileHandle?.synchronize()
        try? fileHandle?.close()
        fileHandle = nil
        isRecording = false
        logger.info("⏹️ Session recording saved. Total frames: \(self.framesRecorded)")
    }
}