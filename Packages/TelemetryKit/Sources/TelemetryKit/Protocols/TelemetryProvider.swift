import Foundation

public struct RecordingState: Sendable, Equatable {
    public let isRecording: Bool
    public let isPaused: Bool
    public let currentFileURL: URL?
    public let droppedFrameCount: UInt64

    public var isCaptureDegraded: Bool {
        droppedFrameCount > 0
    }

    public init(
        isRecording: Bool,
        isPaused: Bool,
        currentFileURL: URL?,
        droppedFrameCount: UInt64 = 0
    ) {
        self.isRecording = isRecording
        self.isPaused = isPaused
        self.currentFileURL = currentFileURL
        self.droppedFrameCount = droppedFrameCount
    }

    public static let idle = RecordingState(
        isRecording: false,
        isPaused: false,
        currentFileURL: nil
    )
}

public protocol TelemetryProvider: Sendable {
    func telemetryStream() async -> AsyncStream<TelemetryPacket>

    func start(ipAddress: String) async throws
    func stop() async
}

/// Optional capability for providers that can persist incoming telemetry frames.
public protocol TelemetryRecordable: Sendable {
    func recordingStateStream() -> AsyncStream<RecordingState>
    func currentRecordingState() async -> RecordingState
    func setAutoRecordingEnabled(_ enabled: Bool) async
    func startManualRecording() async throws -> URL
    func stopRecording() async
}