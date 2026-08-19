import Foundation
import OSLog

public enum RecordedSessionError: Error, Equatable, Sendable {
    case fileNotFound(URL)
    case invalidHeader
    case unsupportedHeader(RaceFileHeader)
    case truncatedFrame(expected: Int, actual: Int)
    case playbackStreamFinished
}

/// Reads a recorded .race file and streams it as TelemetryPackets matching live 60Hz behavior.
///
/// A provider owns one telemetry stream. Once playback reaches EOF or fails validation,
/// that stream is finished and the provider cannot be restarted. Create a new provider
/// for another playback session.
public actor RecordedSessionProvider: TelemetryProvider {
    private let logger = Logger(subsystem: "com.raceengineer", category: "RecordedSessionProvider")
    
    private let fileURL: URL
    private let playbackSpeed: Double
    private var playbackTask: Task<Void, Never>?
    private var hasFinishedStream = false
    
    private let streamInstance: AsyncStream<TelemetryPacket>
    private var streamContinuation: AsyncStream<TelemetryPacket>.Continuation?

    public init(fileURL: URL, playbackSpeed: Double = 1.0) {
        self.fileURL = fileURL
        self.playbackSpeed = max(0.1, playbackSpeed)
        
        var localContinuation: AsyncStream<TelemetryPacket>.Continuation?
        self.streamInstance = AsyncStream(bufferingPolicy: .bufferingNewest(5)) { continuation in
            localContinuation = continuation
        }
        self.streamContinuation = localContinuation
    }

    public func telemetryStream() async -> AsyncStream<TelemetryPacket> {
        return streamInstance
    }

    // MARK: - Playback Lifecycle

    public func start(ipAddress: String = "") async throws {
        guard !hasFinishedStream else {
            throw RecordedSessionError.playbackStreamFinished
        }

        stop()

        guard let handle = try? FileHandle(forReadingFrom: fileURL) else {
            logger.error("❌ Cannot open recording at path: \(self.fileURL.path)")
            hasFinishedStream = true
            streamContinuation?.finish()
            throw RecordedSessionError.fileNotFound(fileURL)
        }

        // Validate 16-byte header magic and format
        guard let headerData = try? handle.read(upToCount: RaceFileHeader.headerSize),
              headerData.count == RaceFileHeader.headerSize,
              let header = RaceFileHeader.deserialize(from: headerData) else {
            logger.error("❌ Corrupt or invalid .race file header at: \(self.fileURL.lastPathComponent)")
            try? handle.close()
            hasFinishedStream = true
            streamContinuation?.finish()
            throw RecordedSessionError.invalidHeader
        }

        guard header.magic == RaceFileHeader.expectedMagic else {
            logger.error("❌ Invalid .race file magic at: \(self.fileURL.lastPathComponent)")
            try? handle.close()
            hasFinishedStream = true
            streamContinuation?.finish()
            throw RecordedSessionError.invalidHeader
        }

        guard header.isValid else {
            logger.error("❌ Unsupported .race file header at: \(self.fileURL.lastPathComponent)")
            try? handle.close()
            hasFinishedStream = true
            streamContinuation?.finish()
            throw RecordedSessionError.unsupportedHeader(header)
        }

        let packetSize = Int(header.packetSize)
        let sampleRate = Double(header.sampleRate)
        let effectivePlaybackSpeed = self.playbackSpeed

        guard let endOffset = try? handle.seekToEnd() else {
            try? handle.close()
            hasFinishedStream = true
            streamContinuation?.finish()
            throw RecordedSessionError.fileNotFound(fileURL)
        }

        let payloadSize = endOffset - UInt64(RaceFileHeader.headerSize)
        let trailingBytes = payloadSize % UInt64(packetSize)
        guard trailingBytes == 0 else {
            logger.error("❌ Incomplete telemetry frame in \(self.fileURL.lastPathComponent)")
            try? handle.close()
            hasFinishedStream = true
            streamContinuation?.finish()
            throw RecordedSessionError.truncatedFrame(
                expected: packetSize,
                actual: Int(trailingBytes)
            )
        }

        try? handle.seek(toOffset: UInt64(RaceFileHeader.headerSize))

        logger.info("▶️ Starting playback from \(self.fileURL.lastPathComponent) at \(self.playbackSpeed)x speed (\(sampleRate)Hz, \(packetSize) bytes/packet)")

        guard let continuation = self.streamContinuation else {
            try? handle.close()
            return
        }

        let logger = self.logger
        let fileName = self.fileURL.lastPathComponent
        hasFinishedStream = true

        playbackTask = Task.detached(priority: .userInitiated) { [logger, fileName] in
            defer {
                try? handle.close()
                continuation.finish()
                logger.info("🏁 Session playback finished.")
            }

            let clock = ContinuousClock()
            let intervalNanoseconds = Int64(1_000_000_000.0 / (sampleRate * effectivePlaybackSpeed))
            let interval = Duration.nanoseconds(intervalNanoseconds)
            var targetTime = clock.now

            while !Task.isCancelled {
                guard let frameBuffer = try? handle.read(upToCount: packetSize) else {
                    break // End of stream reached
                }

                guard frameBuffer.count == packetSize else {
                    logger.error("❌ Truncated telemetry frame in \(fileName)")
                    break
                }

                // Ingress through single-pass packet parser
                let packet = GT7Packet(decryptedData: frameBuffer)
                continuation.yield(packet)

                targetTime += interval
                let sleepDuration = targetTime - clock.now
                if sleepDuration > .zero {
                    try? await Task.sleep(for: sleepDuration)
                }
            }
        }
    }

    public func stop() {
        playbackTask?.cancel()
        playbackTask = nil
        logger.info("⏹️ Session playback stopped")
    }
}