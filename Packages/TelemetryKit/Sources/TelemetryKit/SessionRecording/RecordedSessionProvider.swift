import Foundation
import OSLog

/// Reads recorded .race binary files and streams them as TelemetryPackets matching live 60Hz behavior.
public actor RecordedSessionProvider: TelemetryProvider {
    private let logger = Logger(subsystem: "com.raceengineer", category: "RecordedSessionProvider")
    
    private let fileURL: URL
    private let playbackSpeed: Double
    private var playbackTask: Task<Void, Never>?
    
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

    nonisolated public func telemetryStream() -> AsyncStream<TelemetryPacket> {
        return streamInstance
    }

    // MARK: - TelemetryProvider Protocol Conformance (Recording Stubs)

    nonisolated public func recordingStateStream() -> AsyncStream<RecordingState> {
        AsyncStream { continuation in
            continuation.yield(.idle)
            continuation.finish()
        }
    }

    public func setAutoRecordingEnabled(_ enabled: Bool) async {
        // No-op for recorded session playback
    }

    public func startManualRecording() async throws -> URL {
        throw NSError(
            domain: "com.raceengineer.RecordedSessionProvider",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Cannot record during session playback."]
        )
    }

    public func stopRecording() async {
        // No-op for recorded session playback
    }

    // MARK: - Playback Lifecycle

    public func start(ipAddress: String = "") async throws {
        stop()

        guard let handle = try? FileHandle(forReadingFrom: fileURL) else {
            logger.error("❌ Cannot open recording at path: \(self.fileURL.path)")
            streamContinuation?.finish()
            return
        }

        // Validate 16-byte header magic and format
        guard let headerData = try? handle.read(upToCount: RaceFileHeader.headerSize),
              headerData.count == RaceFileHeader.headerSize,
              let header = RaceFileHeader.deserialize(from: headerData),
              header.isValid else {
            logger.error("❌ Corrupt or invalid .race file header at: \(self.fileURL.lastPathComponent)")
            try? handle.close()
            streamContinuation?.finish()
            return
        }

        let packetSize = Int(header.packetSize)
        let sampleRate = Double(header.sampleRate)
        let effectivePlaybackSpeed = self.playbackSpeed

        logger.info("▶️ Starting playback from \(self.fileURL.lastPathComponent) at \(self.playbackSpeed)x speed (\(sampleRate)Hz, \(packetSize) bytes/packet)")

        guard let continuation = self.streamContinuation else {
            try? handle.close()
            return
        }

        playbackTask = Task.detached(priority: .userInitiated) { [weak self] in
            defer {
                try? handle.close()
                continuation.finish()
                self?.logger.info("🏁 Session playback finished.")
            }

            let clock = ContinuousClock()
            let intervalNanoseconds = Int64(1_000_000_000.0 / (sampleRate * effectivePlaybackSpeed))
            let interval = Duration.nanoseconds(intervalNanoseconds)
            var targetTime = clock.now

            while !Task.isCancelled {
                guard let frameBuffer = try? handle.read(upToCount: packetSize),
                      frameBuffer.count == packetSize else {
                    break // End of stream reached
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