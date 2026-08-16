import Foundation
import Network
import OSLog
import os

/// Handles the UDP connection to GT7 matching the Packet C (368-byte) specification.
public actor GT7TelemetryProvider: TelemetryProvider {
    private enum TelemetryConfig {
        static let inboundPort: NWEndpoint.Port = 33740 
        static let outboundPort: NWEndpoint.Port = 33739 
        static let heartbeatMessage: [UInt8] = [0x43]   // ASCII 'C'
        static let heartbeatInterval: UInt64 = 10        
        static let expectedMagic: UInt32 = 0x47375330   // "0S7G" / "G7S0"
    }

    private let logger = Logger(subsystem: "com.raceengineer", category: "Telemetry")
    private var listener: NWListener?
    private var activeInboundConnection: NWConnection?
    private var heartbeatTask: Task<Void, Never>?
    private let hasLoggedFirstPacket = OSAllocatedUnfairLock(initialState: false)

    private var streamContinuation: AsyncStream<TelemetryPacket>.Continuation?
    private let telemetryStreamInstance: AsyncStream<TelemetryPacket>
    private let networkQueue = DispatchQueue(label: "com.raceengineer.telemetry.network", qos: .userInteractive)

    public init() {
        var localContinuation: AsyncStream<TelemetryPacket>.Continuation?
        self.telemetryStreamInstance = AsyncStream(bufferingPolicy: .bufferingNewest(5)) { continuation in
            localContinuation = continuation
        }
        self.streamContinuation = localContinuation
    }

    nonisolated public func telemetryStream() -> AsyncStream<TelemetryPacket> {
        return telemetryStreamInstance
    }

    public func start(ipAddress: String) async throws {
        stop()
        hasLoggedFirstPacket.withLock { $0 = false }

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
        logger.info("🚀 GT7 Provider Started (Packet C). Local: \(TelemetryConfig.inboundPort.rawValue), Target: \(ipAddress):\(TelemetryConfig.outboundPort.rawValue)")
    }

    public func stop() {
        heartbeatTask?.cancel()
        heartbeatTask = nil

        activeInboundConnection?.cancel()
        activeInboundConnection = nil

        listener?.cancel()
        listener = nil

        logger.info("⏹️ Telemetry provider stopped")
    }

    // MARK: - Inbound Connection Handling

    private func handleListenerState(_ state: NWListener.State) {
        logger.info("👂 Listener State: \(String(describing: state)) on \(TelemetryConfig.inboundPort.rawValue)")
    }

    private func handleNewInboundConnection(_ connection: NWConnection) {
        activeInboundConnection?.cancel()
        activeInboundConnection = connection

        logger.info("📡 Inbound data connection established from \(connection.endpoint.debugDescription)")
        connection.start(queue: networkQueue)

        guard let continuation = self.streamContinuation else { return }
        let logger = self.logger
        let firstPacketLock = self.hasLoggedFirstPacket

        Self.listenNextPacket(
            on: connection,
            continuation: continuation,
            logger: logger,
            firstPacketLock: firstPacketLock
        )
    }

    private nonisolated static func listenNextPacket(
        on connection: NWConnection,
        continuation: AsyncStream<TelemetryPacket>.Continuation,
        logger: Logger,
        firstPacketLock: OSAllocatedUnfairLock<Bool>
    ) {
        connection.receiveMessage { content, _, _, error in
            // Re-arm immediately for the next packet on the network queue
            if error == nil {
                listenNextPacket(
                    on: connection,
                    continuation: continuation,
                    logger: logger,
                    firstPacketLock: firstPacketLock
                )
            }

            guard let data = content, data.count == 368 else {
                if let error {
                    logger.debug("📥 Receive error: \(error.localizedDescription)")
                }
                return
            }

            // Decrypt and validate
            let decrypted = Salsa20.decrypt(data: data)
            let packet = GT7Packet(decryptedData: decrypted)

            if packet.magic == TelemetryConfig.expectedMagic {
                continuation.yield(packet)
                
                let shouldLog = firstPacketLock.withLock { isLogged -> Bool in
                    if !isLogged {
                        isLogged = true
                        return true
                    }
                    return false
                }
                
                if shouldLog {
                    logger.info("✅ First valid GT7 Packet C telemetry frame streaming at 60Hz")
                }
            }
        }
    }

    // MARK: - Heartbeat

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