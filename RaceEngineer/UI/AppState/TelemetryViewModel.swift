import SwiftUI
import Observation
import OSLog
import TelemetryKit

@Observable
@MainActor
public class TelemetryViewModel {
    private let logger = Logger(subsystem: "com.raceengineer", category: "ViewModel")

    // MARK: - Domain-Isolated Value Snapshots (UDF State)
    public var motion: MotionState = .idle
    public var engine: EngineState = .idle
    public var inputs: DriverInputState = .idle
    public var tires: TireState = .cold
    public var timing: LapTimingState = .empty
    public var carCode: Int32? = nil

    // MARK: - Connection & Session State
    public var isConnected = false
    public var isConnecting = false
    public var connectionError: String?

    // MARK: - Backward-Compatibility Accessors
    public var speedKmh: Float { motion.speedKmh }
    public var speedMph: Float { motion.speedMph }
    public var engineRPM: Float { engine.rpm }
    public var gear: Int { motion.gear }
    public var throttle: Float { inputs.throttle }
    public var brake: Float { inputs.brake }
    public var clutch: Float { inputs.clutch }
    public var tireTemps: TireData<Float> { tires.surfaceTemps }
    public var oilTemp: Float { engine.oilTemp }
    public var waterTemp: Float { engine.waterTemp }
    public var fuelLevel: Float { engine.fuelLevel }
    public var fuelCapacity: Float { engine.fuelCapacity }
    public var currentLapNumber: Int { timing.currentLapNumber }

    // MARK: - Infrastructure & Transport
    private var provider: (any TelemetryProvider)?
    private var streamTask: Task<Void, Never>?

    public init(provider: (any TelemetryProvider)? = nil) {
        self.provider = provider
    }

    // MARK: - User Intents & Actions

    public func connect(ipAddress: String, isMock: Bool = false) {
        isConnected = false
        isConnecting = true
        connectionError = nil

        let selectedProvider: any TelemetryProvider = provider ?? (isMock ? MockTelemetryProvider() : GT7TelemetryProvider())
        self.provider = selectedProvider

        Task {
            do {
                try await selectedProvider.start(ipAddress: ipAddress)
                self.isConnected = true
                self.isConnecting = false
                self.logger.info("✅ Telemetry provider connected to \(ipAddress)")

                // Start listening to stream
                self.streamTask?.cancel()
                self.streamTask = Task { [weak self] in
                    let stream = selectedProvider.telemetryStream()
                    for await packet in stream {
                        if Task.isCancelled { break }
                        self?.update(with: packet)
                    }
                }
            } catch {
                self.connectionError = "Failed to connect: \(error.localizedDescription)"
                self.isConnected = false
                self.isConnecting = false
                self.logger.error("❌ Telemetry connection failed: \(error.localizedDescription)")
            }
        }
    }

    public func disconnect() {
        Task {
            await provider?.stop()
            streamTask?.cancel()
            streamTask = nil
            isConnected = false
            isConnecting = false
            logger.info("⏹️ Telemetry disconnected by user")
        }
    }

    // MARK: - 60Hz Hot Path Snapshot Updates

    private func update(with packet: TelemetryPacket) {
        // Construct stack-allocated value types with zero heap allocation
        self.carCode = packet.carCode

        self.motion = MotionState(
            speedMph: packet.speedMph,
            speedKmh: packet.speedKmh,
            gear: packet.gear,
            suggestedGear: packet.suggestedGear
        )

        self.engine = EngineState(
            rpm: packet.engineRPM,
            maxRPM: 8500, // Normalized default rev limit
            oilTemp: packet.oilTemp,
            waterTemp: packet.waterTemp,
            fuelLevel: packet.fuelLevel,
            fuelCapacity: packet.fuelCapacity,
            turboBoost: packet.turboBoost
        )

        self.inputs = DriverInputState(
            throttle: packet.throttle,
            brake: packet.brake,
            clutch: packet.clutchPedal,
            steeringAngle: packet.steeringAngle
        )

        self.tires = TireState(
            surfaceTemps: packet.tireSurfaceTemps,
            activeTorque: packet.activeTorque,
            suspensionTravel: packet.suspensionTravel
        )

        self.timing = LapTimingState(
            currentLapNumber: packet.currentLapNumber,
            racePosition: packet.racePosition,
            totalCars: packet.totalCars,
            currentLapTime: packet.currentLapTime,
            lastLapTime: packet.lastLapTime,
            bestLapTime: packet.bestLapTime
        )
    }
}
