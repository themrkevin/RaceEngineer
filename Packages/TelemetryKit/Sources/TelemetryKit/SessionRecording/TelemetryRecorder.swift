import Foundation
import OSLog
import os

/// Handles high-performance 60Hz telemetry recording to .race binary files with zero hot-path allocations.
public actor TelemetryRecorder {
    private let logger = Logger(subsystem: "com.raceengineer", category: "TelemetryRecorder")

    // State Tracking
    private var isAutoRecordingEnabled = false
    private var isRecording = false
    private var isPaused = false
    private var currentFileURL: URL?
    private var fileHandle: FileHandle?
    private var droppedFrameCount: UInt64 = 0
    private var acceptedFrameCount: UInt64 = 0
    private var skippedPausedFrameCount: UInt64 = 0
    private var loggedDisabledFrame = false
    private var loggedPausedFrame = false
    private var loggedTelemetryGap = false
    
    private var lastPacketTimestamp = ContinuousClock.now
    private var processingTask: Task<Void, Never>?
    private var watchdogTask: Task<Void, Never>?

    // Disk Write Batching (reduces disk write syscalls by 30x)
    private var writeBuffer = Data()
    private static let maxBufferedBytes = 368 * 30 // Flush every 30 frames (~0.5s)

    // Reactive State Stream
    private var stateContinuation: AsyncStream<RecordingState>.Continuation?
    public let stateStream: AsyncStream<RecordingState>

    // Lossless ingress stream for non-blocking 60Hz frame handoff.
    // The writer task drains this channel and applies batched disk I/O.
    private let frameContinuation: AsyncStream<(Data, Bool)>.Continuation
    private let pendingIngressCount = OSAllocatedUnfairLock(initialState: UInt64(0))
    private let ingressDroppedFrameCount = OSAllocatedUnfairLock(initialState: UInt64(0))

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
        let frameStream = AsyncStream<(Data, Bool)>(bufferingPolicy: .unbounded) { continuation in
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
            currentFileURL: currentFileURL,
            droppedFrameCount: droppedFrameCount
        )
        stateContinuation?.yield(state)
    }

    // MARK: - Configuration & Public API

    public func currentRecordingState() -> RecordingState {
        RecordingState(
            isRecording: isRecording,
            isPaused: isPaused,
            currentFileURL: currentFileURL,
            droppedFrameCount: droppedFrameCount
        )
    }

    public func setAutoRecordingEnabled(_ enabled: Bool) async {
        self.isAutoRecordingEnabled = enabled
        logger.info("🎙️ Recorder auto-recording state: \(enabled, privacy: .public)")
        if !enabled && self.isRecording {
            await flushIngress()
            self.performStopRecording()
        }
    }

    public func startManualRecording() async throws -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let timestamp = Self.fileNameDateFormatter.string(from: Date())
        let fileURL = docs.appendingPathComponent("GT7_Manual_\(timestamp).race")

        await flushIngress()
        try self.performStartRecording(to: fileURL)
        logger.info("🖐️ Manual recording active: \(self.isRecording, privacy: .public), file=\(fileURL.lastPathComponent, privacy: .public)")
        return fileURL
    }

    public func startRecording(to fileURL: URL) async throws {
        await flushIngress()
        try self.performStartRecording(to: fileURL)
    }

    public func stopRecording() async {
        await flushIngress()
        self.performStopRecording()
    }

    /// Waits until all frames accepted by the ingress channel have been processed.
    public func flushIngress() async {
        while pendingIngressCount.withLock({ $0 > 0 }) {
            try? await Task.sleep(for: .milliseconds(1))
        }
        flushBuffer()
    }

    // MARK: - 60Hz Lossless Ingress (nonisolated)

    /// Hands frames to the writer channel without evicting older frames when the writer is busy.
    nonisolated public func processFrameDirect(rawData: Data, isGamePaused: Bool) {
        pendingIngressCount.withLock { count in
            count += 1
        }
        let result = frameContinuation.yield((rawData, isGamePaused))
        if case .enqueued = result {
            return
        } else {
            pendingIngressCount.withLock { count in
                count = count > 0 ? count - 1 : 0
            }
        }

        if case .dropped = result {
            ingressDroppedFrameCount.withLock { count in
                count += 1
            }
        }
    }

    /// Direct frame recording helper for testing.
    public func recordFrame(_ rawData: Data, isGamePaused: Bool = false) {
        processSingleFrame(rawData: rawData, isGamePaused: isGamePaused)
    }

    // MARK: - Processing & Watchdog Loops

    private func processFrameLoop(stream: AsyncStream<(Data, Bool)>) async {
        for await (data, isPaused) in stream {
            if Task.isCancelled { break }
            updateDroppedFrameCountIfNeeded()
            processSingleFrame(rawData: data, isGamePaused: isPaused)
            pendingIngressCount.withLock { count in
                count = count > 0 ? count - 1 : 0
            }
        }
    }

    private func updateDroppedFrameCountIfNeeded() {
        let newlyDropped = ingressDroppedFrameCount.withLock { count -> UInt64 in
            defer { count = 0 }
            return count
        }

        guard newlyDropped > 0 else { return }
        droppedFrameCount += newlyDropped
        logger.error("⚠️ Telemetry recording degraded: dropped \(newlyDropped) ingress frame(s), total \(self.droppedFrameCount)")
        broadcastState()
    }

    private func processSingleFrame(rawData: Data, isGamePaused: Bool) {
        guard self.isAutoRecordingEnabled || self.isRecording else {
            if !loggedDisabledFrame {
                loggedDisabledFrame = true
                logger.error("⚠️ Telemetry frame received while recorder is disabled; no frames will be persisted")
            }
            return
        }

        self.lastPacketTimestamp = ContinuousClock.now
        self.loggedTelemetryGap = false

        if isGamePaused {
            skippedPausedFrameCount += 1
            if !loggedPausedFrame {
                loggedPausedFrame = true
                logger.warning("⚠️ Telemetry packet marked paused; recording continues because pause mapping is provisional")
            }
        }

        if !self.isRecording {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let timestamp = Self.fileNameDateFormatter.string(from: Date())
            let fileURL = docs.appendingPathComponent("GT7_Session_\(timestamp).race")
            try? self.performStartRecording(to: fileURL)
        }

        // Buffer frame into contiguous memory
        self.writeBuffer.append(rawData)
        acceptedFrameCount += 1

        if acceptedFrameCount == 1 {
            logger.info("✅ First telemetry frame accepted for recording")
        } else if acceptedFrameCount % 600 == 0 {
            logger.info("📼 Recording checkpoint: accepted=\(self.acceptedFrameCount), pausedSkipped=\(self.skippedPausedFrameCount), bufferedBytes=\(self.writeBuffer.count)")
        }

        if self.writeBuffer.count >= Self.maxBufferedBytes {
            self.flushBuffer()
        }
    }

    // Diagnostic only: never mutates recording state. Real disconnects are handled via transport
    // (NWListener) state in GT7TelemetryProvider, not by guessing from packet timing.
    private func watchdogMonitorLoop() async {
        let clock = ContinuousClock()
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            if self.isRecording && !self.loggedTelemetryGap && (clock.now - self.lastPacketTimestamp) > .seconds(3.5) {
                self.loggedTelemetryGap = true
                self.logger.warning("⚠️ Telemetry gap detected: no packets for >3.5s, recording continues")
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
        self.droppedFrameCount = 0
        self.acceptedFrameCount = 0
        self.skippedPausedFrameCount = 0
        self.loggedDisabledFrame = false
        self.loggedPausedFrame = false
        self.loggedTelemetryGap = false
        ingressDroppedFrameCount.withLock { count in
            count = 0
        }
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

        updateDroppedFrameCountIfNeeded()
        flushBuffer()

        let finalByteCount = (fileHandle?.offsetInFile ?? UInt64(RaceFileHeader.headerSize)) + UInt64(writeBuffer.count)
        logger.info("📼 Recording finalized: frames=\(self.acceptedFrameCount), pausedSkipped=\(self.skippedPausedFrameCount), dropped=\(self.droppedFrameCount), bytes=\(finalByteCount)")

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