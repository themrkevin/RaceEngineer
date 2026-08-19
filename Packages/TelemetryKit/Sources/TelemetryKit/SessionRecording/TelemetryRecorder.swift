import Foundation
import OSLog

public final class TelemetryRecorder: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.raceengineer.recorder.queue", qos: .utility)
    private let logger = Logger(subsystem: "com.raceengineer", category: "TelemetryRecorder")

    // State Tracking
    private var isAutoRecordingEnabled = false
    private var isRecording = false
    private var isPaused = false
    private var currentFileURL: URL?
    private var fileHandle: FileHandle?
    private var watchdogTimer: DispatchSourceTimer?

    private var stateContinuation: AsyncStream<RecordingState>.Continuation?
    public let stateStream: AsyncStream<RecordingState>

    public init() {
        var localContinuation: AsyncStream<RecordingState>.Continuation?
        self.stateStream = AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            localContinuation = continuation
        }
        self.stateContinuation = localContinuation
        broadcastState()
    }

    // MARK: - Reactive Stream

    private func broadcastState() {
        let state = RecordingState(
            isRecording: isRecording,
            isPaused: isPaused,
            currentFileURL: currentFileURL
        )
        stateContinuation?.yield(state)
    }

    // MARK: - Configuration & Public API

    public func setAutoRecordingEnabled(_ enabled: Bool) {
        queue.async {
            self.isAutoRecordingEnabled = enabled
            if !enabled && self.isRecording {
                self.performStopRecording()
            }
        }
    }

    public func startManualRecording() async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
                    let fileURL = docs.appendingPathComponent("GT7_Manual_\(timestamp).race")
                    
                    try self.performStartRecording(to: fileURL)
                    continuation.resume(returning: fileURL)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func stopRecording() {
        queue.async {
            self.performStopRecording()
        }
    }

    // MARK: - 60Hz Non-Allocating Hot Path Ingress

    /// Synchronously consumes frames directly on the UDP receive queue with zero heap allocations.
    public func processFrameDirect(rawData: Data, isGamePaused: Bool) {
        queue.async {
            guard self.isAutoRecordingEnabled || self.isRecording else { return }

            self.resetWatchdog()

            if isGamePaused {
                if !self.isPaused {
                    self.isPaused = true
                    self.broadcastState()
                    self.logger.info("⏸️ Telemetry recording suspended (Paused).")
                }
                return
            }

            if self.isPaused {
                self.isPaused = false
                self.broadcastState()
                self.logger.info("▶️ Telemetry recording resumed.")
            }

            if !self.isRecording {
                let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
                let fileURL = docs.appendingPathComponent("GT7_Session_\(timestamp).race")
                try? self.performStartRecording(to: fileURL)
            }

            self.fileHandle?.write(rawData)
        }
    }

    // MARK: - File I/O (Queue-Confined)

    private func performStartRecording(to fileURL: URL) throws {
        performStopRecording()

        self.currentFileURL = fileURL
        FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: fileURL)

        var header = Data()
        var magic: UInt32 = 0x52414345         // "RACE"
        var version: UInt16 = 1                // v1
        var packetSize: UInt16 = 368           // 368 bytes
        var sampleRate: UInt16 = 60            // 60Hz
        var flags: UInt16 = 0
        var reserved: UInt32 = 0

        header.append(Data(bytes: &magic, count: 4))
        header.append(Data(bytes: &version, count: 2))
        header.append(Data(bytes: &packetSize, count: 2))
        header.append(Data(bytes: &sampleRate, count: 2))
        header.append(Data(bytes: &flags, count: 2))
        header.append(Data(bytes: &reserved, count: 4))

        handle.write(header)
        self.fileHandle = handle
        self.isRecording = true
        self.isPaused = false
        broadcastState()

        logger.info("🔴 Session recording started: \(fileURL.lastPathComponent)")
    }

    private func performStopRecording() {
        guard isRecording else { return }

        watchdogTimer?.cancel()
        watchdogTimer = nil

        try? fileHandle?.synchronize()
        try? fileHandle?.close()
        fileHandle = nil

        self.isRecording = false
        self.isPaused = false
        broadcastState()

        if let url = currentFileURL {
            logger.info("⏹️ Session saved cleanly to: \(url.lastPathComponent)")
        }
    }

    private func resetWatchdog() {
        watchdogTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + .milliseconds(3500))
        timer.setEventHandler { [weak self] in
            guard let self, self.isRecording else { return }
            self.logger.info("🏁 Packet stream ended. Auto-sealing file.")
            self.performStopRecording()
        }
        timer.resume()
        self.watchdogTimer = timer
    }
    
    // MARK: - Testing & Direct File Controls

    /// Starts recording explicitly to a target file URL (used in tests and custom exports).
    public func startRecording(to fileURL: URL) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    try self.performStartRecording(to: fileURL)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Direct frame recording helper for testing.
    public func recordFrame(_ rawData: Data, isGamePaused: Bool = false) async {
        await withCheckedContinuation { continuation in
            queue.async {
                self.processFrameDirect(rawData: rawData, isGamePaused: isGamePaused)
                continuation.resume()
            }
        }
    }

    /// Stops recording asynchronously ensuring all queued disk writes are flushed.
    public func stopRecording() async {
        await withCheckedContinuation { continuation in
            queue.async {
                self.performStopRecording()
                continuation.resume()
            }
        }
    }
}