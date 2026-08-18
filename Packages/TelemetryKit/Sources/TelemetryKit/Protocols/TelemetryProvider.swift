import Foundation

/// Defines a source of telemetry data (GT7, F1 24, or a Mock/Replay source).
public protocol TelemetryProvider: Sendable {
    /// Provides a stream of telemetry packets at the game's native frequency (e.g., 60Hz).
    nonisolated func telemetryStream() -> AsyncStream<TelemetryPacket>
    
    /// Starts the connection and heartbeat.
    /// - Parameter ipAddress: The IP address of the console/PC.
    func start(ipAddress: String) async throws
    
    /// Gracefully shuts down the networking.
    func stop() async
}
