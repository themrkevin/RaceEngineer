import Foundation
import Network
import OSLog
import os

public actor GT7TelemetryProvider: TelemetryProvider, TelemetryRecordable {
    private enum TelemetryConfig {
        static let inboundPort: NWEndpoint.Port = 33740 
        static let outboundPort: NWEndpoint.Port = 33739 
        static let heartbeatMessage: [UInt8] = [0x43]
        static let heartbeatInterval: UInt64 = 10        
        static let expectedMagic: UInt32 = 0x47375330
    }

    private let logger = Logger(subsystem: "com.raceengineer", category: "Telemetry")
    private var listener: NWListener?
    private var activeInboundConnection: NWConnection?
    private var heartbeatTask: Task<Void, Never>?
    private let hasLoggedFirstPacket = OSAllocatedUnfairLock(initialState: false)

    private let recorder = TelemetryRecorder()
    private var streamContinuation: AsyncStream<TelemetryPacket>.Continuation?
    private var telemetryStreamInstance: AsyncStream<TelemetryPacket>
    private let networkQueue = DispatchQueue(label: "com.raceengineer.telemetry.network", qos: .userInteractive)
    private let packetDiagnostics = OSAllocatedUnfairLock(initialState: PacketDiagnostics())

    private struct PacketDiagnostics: Sendable {
        var validPacketCount: UInt64 = 0
        var pausedPacketCount: UInt64 = 0
        var hasLoggedFirstPacket = false
    }

    public init() {
        var localContinuation: AsyncStream<TelemetryPacket>.Continuation?
        self.telemetryStreamInstance = AsyncStream(bufferingPolicy: .bufferingNewest(5)) { continuation in
            localContinuation = continuation
        }
        self.streamContinuation = localContinuation
    }

    public func telemetryStream() async -> AsyncStream<TelemetryPacket> {
        return telemetryStreamInstance
    }

    nonisolated public func recordingStateStream() -> AsyncStream<RecordingState> {
        return recorder.stateStream
    }

    public func currentRecordingState() async -> RecordingState {
        await recorder.currentRecordingState()
    }

    public func setAutoRecordingEnabled(_ enabled: Bool) async {
        logger.info("🎙️ Auto-recording requested: \(enabled, privacy: .public)")
        await recorder.setAutoRecordingEnabled(enabled)
    }

    public func startManualRecording() async throws -> URL {
        let url = try await recorder.startManualRecording()
        logger.info("🎙️ Manual recording started: \(url.lastPathComponent, privacy: .public)")
        return url
    }

    public func stopRecording() async {
        logger.info("🎙️ Manual recording stop requested")
        await recorder.stopRecording()
    }

    public func start(ipAddress: String) async throws {
        await stop()
        resetTelemetryStream()
        hasLoggedFirstPacket.withLock { $0 = false }
        packetDiagnostics.withLock { diagnostics in
            diagnostics = PacketDiagnostics()
        }

        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true

        do {
            let listener = try NWListener(using: parameters, on: TelemetryConfig.inboundPort)
            self.listener = listener

            listener.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                Task { await self.handleListenerState(state) }
            }

            listener.newConnectionHandler = { [weak self] connection in
                guard let self else { return }
                Task { await self.handleNewInboundConnection(connection) }
            }

            listener.start(queue: networkQueue)
        } catch {
            logger.error("❌ Failed to start listener: \(error.localizedDescription)")
            throw error
        }

        startHeartbeat(ipAddress: ipAddress)
        logger.info("🚀 GT7 Provider Started (Packet C). Target: \(ipAddress)")
    }

    private func resetTelemetryStream() {
        var localContinuation: AsyncStream<TelemetryPacket>.Continuation?
        telemetryStreamInstance = AsyncStream(bufferingPolicy: .bufferingNewest(5)) { continuation in
            localContinuation = continuation
        }
        streamContinuation = localContinuation
        logger.info("🔄 Created fresh telemetry stream for connection")
    }

    public func stop() async {
        heartbeatTask?.cancel()
        heartbeatTask = nil

        activeInboundConnection?.cancel()
        activeInboundConnection = nil

        listener?.cancel()
        listener = nil

        await recorder.stopRecording()
        logger.info("⏹️ Telemetry provider stopped")
    }

    private func handleListenerState(_ state: NWListener.State) {
        logger.info("👂 Listener State: \(String(describing: state))")
    }

    private func handleNewInboundConnection(_ connection: NWConnection) {
        activeInboundConnection?.cancel()
        activeInboundConnection = connection
        connection.start(queue: networkQueue)
        logger.info("📡 GT7 inbound telemetry connection established")

        guard let continuation = self.streamContinuation else { return }
        let recorder = self.recorder
        let logger = self.logger
        let firstPacketLock = self.hasLoggedFirstPacket
        let packetDiagnostics = self.packetDiagnostics

        Self.listenNextPacket(
            on: connection,
            continuation: continuation,
            recorder: recorder,
            logger: logger,
            firstPacketLock: firstPacketLock,
            packetDiagnostics: packetDiagnostics
        )
    }

    private nonisolated static func listenNextPacket(
        on connection: NWConnection,
        continuation: AsyncStream<TelemetryPacket>.Continuation,
        recorder: TelemetryRecorder,
        logger: Logger,
        firstPacketLock: OSAllocatedUnfairLock<Bool>,
        packetDiagnostics: OSAllocatedUnfairLock<PacketDiagnostics>
    ) {
        connection.receiveMessage { content, _, _, error in
            if error == nil {
                listenNextPacket(
                    on: connection,
                    continuation: continuation,
                    recorder: recorder,
                    logger: logger,
                    firstPacketLock: firstPacketLock,
                    packetDiagnostics: packetDiagnostics
                )
            }

            guard let data = content, data.count == 368 else { return }

            let decrypted = Salsa20.decrypt(data: data)
            let packet = GT7Packet(decryptedData: decrypted)

            if packet.magic == TelemetryConfig.expectedMagic {
                let diagnostics = packetDiagnostics.withLock { diagnostics -> PacketDiagnostics in
                    diagnostics.validPacketCount += 1
                    if packet.isGamePaused {
                        diagnostics.pausedPacketCount += 1
                    }
                    return diagnostics
                }

                if !diagnostics.hasLoggedFirstPacket {
                    packetDiagnostics.withLock { diagnostics in
                        diagnostics.hasLoggedFirstPacket = true
                    }
                    let rawFlags = String(format: "%04X", packet.rawSessionFlags)
                    logger.info("🔎 First valid packet: seq=\(packet.packetSequence), cars=\(packet.totalCars), paused=\(packet.isGamePaused), rawFlags=0x\(rawFlags)")
                } else if diagnostics.validPacketCount % 600 == 0 {
                    logger.info("🔎 Packet checkpoint: valid=\(diagnostics.validPacketCount), paused=\(diagnostics.pausedPacketCount), seq=\(packet.packetSequence)")
                }

                continuation.yield(packet)
                
                // Pure synchronous queue handoff — NO unmanaged Task allocations
                recorder.processFrameDirect(rawData: decrypted, isGamePaused: packet.isGamePaused)

                let shouldLog = firstPacketLock.withLock { isLogged -> Bool in
                    if !isLogged {
                        isLogged = true
                        return true
                    }
                    return false
                }
                
                if shouldLog {
                    logger.info("✅ Valid GT7 60Hz Telemetry active")
                }
            }
        }
    }

    private func startHeartbeat(ipAddress: String) {
        let host = NWEndpoint.Host(ipAddress)
        let logger = self.logger
        
        heartbeatTask = Task.detached(priority: .userInitiated) {
            let connection = NWConnection(host: host, port: TelemetryConfig.outboundPort, using: .udp)
            connection.start(queue: .global(qos: .userInitiated))
            let payload = Data(TelemetryConfig.heartbeatMessage)

            while !Task.isCancelled {
                connection.send(content: payload, completion: .contentProcessed({ error in
                    if let error {
                        logger.error("❌ [Heartbeat] Send error: \(error.localizedDescription)")
                    }
                }))
                try? await Task.sleep(for: .seconds(TelemetryConfig.heartbeatInterval))
            }
            connection.cancel()
        }
    }
}