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

    public func start(ipAddress: String = "") async throws {
        stop()

        guard let handle = try? FileHandle(forReadingFrom: fileURL) else {
            logger.error("❌ Cannot open recording at path: \(self.fileURL.path)")
            return
        }

        // Validate 16-byte header magic ("RACE" / 0x52414345)
        guard let headerData = try? handle.read(upToCount: 16),
              headerData.count == 16,
              headerData.withUnsafeBytes({ $0.loadUnaligned(fromByteOffset: 0, as: UInt32.self) }) == 0x52414345 else {
            logger.error("❌ Corrupt or invalid .race file header at: \(self.fileURL.lastPathComponent)")
            try? handle.close()
            streamContinuation?.finish()
            return
        }

        logger.info("▶️ Starting playback from \(self.fileURL.lastPathComponent) at \(self.playbackSpeed)x speed")

        // 60Hz default frame cadence: ~16,666,667 nanoseconds
        let frameIntervalNanoseconds = UInt64(16_666_667.0 / playbackSpeed)
        guard let continuation = self.streamContinuation else { return }

        playbackTask = Task.detached(priority: .userInitiated) { [weak self] in
            defer { try? handle.close() }

            while !Task.isCancelled {
                guard let frameBuffer = try? handle.read(upToCount: 368),
                      frameBuffer.count == 368 else {
                    break // End of stream reached
                }

                // Ingress through your existing single-pass parser
                let packet = GT7Packet(decryptedData: frameBuffer)
                continuation.yield(packet)

                try? await Task.sleep(nanoseconds: frameIntervalNanoseconds)
            }

            continuation.finish()
            self?.logger.info("🏁 Session playback finished.")
        }
    }

    public func stop() {
        playbackTask?.cancel()
        playbackTask = nil
        logger.info("⏹️ Session playback stopped")
    }
}