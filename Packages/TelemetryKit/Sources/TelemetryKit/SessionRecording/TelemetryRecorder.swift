import Foundation
import OSLog

/// Handles high-performance 60Hz telemetry recording to .race binary files with zero hot-path allocations.
public actor TelemetryRecorder {
    private let logger = Logger(subsystem: "com.raceengineer", category: "TelemetryRecorder")

    // State Tracking
    private var isAutoRecordingEnabled = false
    private var isRecording = false
    private var isPaused = false
    private var currentFileURL: URL?
    private var fileHandle: FileHandle?
    
    private var lastPacketTimestamp = ContinuousClock.now
    private var processingTask: Task<Void, Never>?
    private var watchdogTask: Task<Void, Never>?

    // Disk Write Batching (reduces disk write syscalls by 30x)
    private var writeBuffer = Data()
    private static let maxBufferedBytes = 368 * 30 // Flush every 30 frames (~0.5s)

    // Reactive State Stream
    private var stateContinuation: AsyncStream<RecordingState>.Continuation?
    public let stateStream: AsyncStream<RecordingState>

    // Ingress Stream for Non-Blocking 60Hz Direct Yields
    private let frameContinuation: AsyncStream<(Data, Bool)>.Continuation

    // Static Date Formatter
    private static let fileNameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH-mm-ss"
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    public init() {
        var localStateContinuation: AsyncStream<RecordingState>.Continuation?
        self.stateStream = AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            continuation.yield(.idle)
            localStateContinuation = continuation
        }
        self.stateContinuation = localStateContinuation

        var localFrameContinuation: AsyncStream<(Data, Bool)>.Continuation!
        let frameStream = AsyncStream<(Data, Bool)>(bufferingPolicy: .bufferingNewest(120)) { continuation in
            localFrameContinuation = continuation
        }
        self.frameContinuation = localFrameContinuation

        self.processingTask = nil
        self.watchdogTask = nil

        // Start background actor loops cleanly after properties are initialized
        Task { [weak self, frameStream] in
            await self?.startBackgroundLoops(frameStream: frameStream)
        }
    }

    private func startBackgroundLoops(frameStream: AsyncStream<(Data, Bool)>) {
        self.processingTask = Task { [weak self] in
            guard let self else { return }
            await self.processFrameLoop(stream: frameStream)
        }

        self.watchdogTask = Task { [weak self] in
            guard let self else { return }
            await self.watchdogMonitorLoop()
        }
    }

    deinit {
        processingTask?.cancel()
        watchdogTask?.cancel()
        frameContinuation.finish()
        stateContinuation?.finish()
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
        self.isAutoRecordingEnabled = enabled
        if !enabled && self.isRecording {
            self.performStopRecording()
        }
    }

    public func startManualRecording() throws -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let timestamp = Self.fileNameDateFormatter.string(from: Date())
        let fileURL = docs.appendingPathComponent("GT7_Manual_\(timestamp).race")

        try self.performStartRecording(to: fileURL)
        return fileURL
    }

    public func startRecording(to fileURL: URL) throws {
        try self.performStartRecording(to: fileURL)
    }

    public func stopRecording() {
        self.performStopRecording()
    }

    // MARK: - 60Hz Non-Allocating Ingress (nonisolated)

    /// Synchronously yields frames directly from UDP network receive callback with zero allocations.
    nonisolated public func processFrameDirect(rawData: Data, isGamePaused: Bool) {
        frameContinuation.yield((rawData, isGamePaused))
    }

    /// Direct frame recording helper for testing.
    public func recordFrame(_ rawData: Data, isGamePaused: Bool = false) {
        processSingleFrame(rawData: rawData, isGamePaused: isGamePaused)
    }

    // MARK: - Processing & Watchdog Loops

    private func processFrameLoop(stream: AsyncStream<(Data, Bool)>) async {
        for await (data, isPaused) in stream {
            if Task.isCancelled { break }
            processSingleFrame(rawData: data, isGamePaused: isPaused)
        }
    }

    private func processSingleFrame(rawData: Data, isGamePaused: Bool) {
        guard self.isAutoRecordingEnabled || self.isRecording else { return }

        self.lastPacketTimestamp = ContinuousClock.now

        if isGamePaused {
            if !self.isPaused {
                self.isPaused = true
                self.flushBuffer()
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
            let timestamp = Self.fileNameDateFormatter.string(from: Date())
            let fileURL = docs.appendingPathComponent("GT7_Session_\(timestamp).race")
            try? self.performStartRecording(to: fileURL)
        }

        // Buffer frame into contiguous memory
        self.writeBuffer.append(rawData)

        if self.writeBuffer.count >= Self.maxBufferedBytes {
            self.flushBuffer()
        }
    }

    private func watchdogMonitorLoop() async {
        let clock = ContinuousClock()
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            if self.isRecording && (clock.now - self.lastPacketTimestamp) > .seconds(3.5) {
                self.logger.info("🏁 Packet stream ended. Auto-sealing file.")
                self.performStopRecording()
            }
        }
    }

    // MARK: - File I/O (Actor-Isolated)

    private func flushBuffer() {
        guard !writeBuffer.isEmpty, let handle = fileHandle else { return }
        try? handle.write(contentsOf: writeBuffer)
        writeBuffer.removeAll(keepingCapacity: true)
    }

    private func performStartRecording(to fileURL: URL) throws {
        performStopRecording()

        self.currentFileURL = fileURL
        FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: fileURL)

        // Write normalized 16-byte header
        let header = RaceFileHeader(
            version: RaceFileHeader.currentVersion,
            packetSize: RaceFileHeader.standardPacketSize,
            sampleRate: RaceFileHeader.standardSampleRate
        )
        try handle.write(contentsOf: header.serialize())

        self.fileHandle = handle
        self.writeBuffer.removeAll(keepingCapacity: true)
        self.isRecording = true
        self.isPaused = false
        self.lastPacketTimestamp = ContinuousClock.now
        broadcastState()

        logger.info("🔴 Session recording started: \(fileURL.lastPathComponent)")
    }

    private func performStopRecording() {
        guard isRecording else { return }

        flushBuffer()

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
}