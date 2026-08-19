import Foundation

public struct RecordingState: Sendable, Equatable {
    public let isRecording: Bool
    public let isPaused: Bool
    public let currentFileURL: URL?

    public static let idle = RecordingState(isRecording: false, isPaused: false, currentFileURL: nil)
}

public protocol TelemetryProvider: Sendable {
    func telemetryStream() -> AsyncStream<TelemetryPacket>
    func recordingStateStream() -> AsyncStream<RecordingState>
    
    func start(ipAddress: String) async throws
    func stop() async
    
    func setAutoRecordingEnabled(_ enabled: Bool) async
    func startManualRecording() async throws -> URL
    func stopRecording() async
}