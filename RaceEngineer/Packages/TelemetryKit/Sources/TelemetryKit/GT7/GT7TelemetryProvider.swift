import Foundation
import Network
import OSLog

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
    private var hasLoggedFirstPacket = false

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
        hasLoggedFirstPacket = false

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
        listenNextPacket(on: connection)
    }

    private func listenNextPacket(on connection: NWConnection) {
        connection.receiveMessage { [weak self] content, _, _, error in
            guard let self else { return }

            // Re-arm immediately for the next packet on the network queue
            if error == nil {
                self.listenNextPacket(on: connection)
            }

            guard let data = content, data.count == 368 else {
                if let error {
                    self.logger.debug("📥 Receive error: \(error.localizedDescription)")
                }
                return
            }

            // Decrypt and validate
            let decrypted = Salsa20.decrypt(data: data)
            let packet = GT7Packet(decryptedData: decrypted)

            if packet.magic == TelemetryConfig.expectedMagic {
                self.streamContinuation?.yield(packet)
                
                if !self.hasLoggedFirstPacket {
                    self.hasLoggedFirstPacket = true
                    self.logger.info("✅ First valid GT7 Packet C telemetry frame streaming at 60Hz")
                }
            }
        }
    }

    // MARK: - Heartbeat

    private func startHeartbeat(ipAddress: String) {
        let host = NWEndpoint.Host(ipAddress)
        
        heartbeatTask = Task.detached(priority: .userInitiated) { [weak self] in
            let connection = NWConnection(host: host, port: TelemetryConfig.outboundPort, using: .udp)
            connection.start(queue: .global(qos: .userInitiated))

            let payload = Data(TelemetryConfig.heartbeatMessage)

            while !Task.isCancelled {
                connection.send(content: payload, completion: .contentProcessed({ error in
                    if let error {
                        print("[Heartbeat] Send error: \(error.localizedDescription)")
                    }
                }))

                try? await Task.sleep(for: .seconds(TelemetryConfig.heartbeatInterval))
            }

            connection.cancel()
        }
    }
}