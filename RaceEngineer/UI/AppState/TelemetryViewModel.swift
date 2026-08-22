import SwiftUI
import Observation
import OSLog
import TelemetryKit

@Observable
@MainActor
public class TelemetryViewModel {
    private let logger = Logger(subsystem: "com.raceengineer", category: "ViewModel")

    // MARK: - 1. Domain Snapshot States (UDF Outputs for Widgets)
    public var motion: MotionState = .idle
    public var engine: EngineState = .idle
    public var inputs: DriverInputState = .idle
    public var tires: TireState = .cold
    public var timing: LapTimingState = .empty
    public var carCode: Int32? = nil
    public var sessionPhase: GT7SessionPhase = .preSession

    // MARK: - 2. Connection & Telemetry Status
    public var isConnected = false
    public var isConnecting = false
    public var connectionError: String?

    // MARK: - 3. Session Recording Status (Engine Outputs)
    public var isRecording = false
    public var isRecordingPaused = false
    public var lastSavedFileURL: URL?

    // MARK: - 4. Driver Settings & Configuration (UI Inputs)
    public var isAutoRecordingEnabled = false {
        didSet {
            Task { [weak self] in
                guard let self else { return }
                guard let recordable = self.provider as? any TelemetryRecordable else { return }
                await recordable.setAutoRecordingEnabled(self.isAutoRecordingEnabled)
            }
        }
    }

    // MARK: - 5. Backward-Compatibility Accessors
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

    // MARK: - 6. Infrastructure & Active Tasks
    private var provider: (any TelemetryProvider)?
    private var streamTask: Task<Void, Never>?
    private var recordingStateTask: Task<Void, Never>?
    private var lifecycleTask: Task<Void, Never>?
    private var receivedPacketCount: UInt64 = 0

    // MARK: - Lifecycle
    public init(provider: (any TelemetryProvider)? = nil) {
        self.provider = provider
    }

    // MARK: - User Intents & Actions

    public func connect(ipAddress: String, isMock: Bool = false) {
        lifecycleTask?.cancel()
        isConnected = false
        isConnecting = true
        connectionError = nil

        let selectedProvider: any TelemetryProvider = provider ?? (isMock ? MockTelemetryProvider() : GT7TelemetryProvider())
        self.provider = selectedProvider

        lifecycleTask = Task { [weak self] in
            guard let self else { return }
            do {
                await self.stopConsumers()
                await selectedProvider.stop()

                if let recordable = selectedProvider as? any TelemetryRecordable {
                    await recordable.setAutoRecordingEnabled(self.isAutoRecordingEnabled)
                }
                try await selectedProvider.start(ipAddress: ipAddress)
                self.isConnected = true
                self.isConnecting = false
                self.logger.info("✅ Telemetry provider connected to \(ipAddress)")

                // 1. Observe 60Hz telemetry stream
                self.streamTask?.cancel()
                let telemetryStream = await selectedProvider.telemetryStream()
                self.streamTask = Task { [weak self] in
                    for await packet in telemetryStream {
                        if Task.isCancelled { break }
                        self?.update(with: packet)
                    }
                }

                // 2. Observe recording state reactively (no manual state flags)
                self.recordingStateTask?.cancel()
                if let recordable = selectedProvider as? any TelemetryRecordable {
                    self.recordingStateTask = Task { [weak self] in
                        for await state in recordable.recordingStateStream() {
                            if Task.isCancelled { break }
                            self?.isRecording = state.isRecording
                            self?.isRecordingPaused = state.isPaused
                            if let url = state.currentFileURL {
                                self?.lastSavedFileURL = url
                            }
                        }
                    }

                    let currentState = await recordable.currentRecordingState()
                    self.apply(recordingState: currentState)
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
        lifecycleTask?.cancel()
        lifecycleTask = Task { [weak self] in
            guard let self else { return }
            await self.stopConsumers()
            await self.provider?.stop()
            isConnected = false
            isConnecting = false
            isRecording = false
            sessionPhase = .preSession
            logger.info("⏹️ Telemetry disconnected by user")
        }
    }

    private func stopConsumers() async {
        let currentStreamTask = streamTask
        let currentRecordingStateTask = recordingStateTask

        streamTask?.cancel()
        recordingStateTask?.cancel()
        streamTask = nil
        recordingStateTask = nil

        await currentStreamTask?.value
        await currentRecordingStateTask?.value
    }

    public func toggleManualRecording() {
        Task {
            guard let recordable = provider as? any TelemetryRecordable else { return }
            if isRecording {
                await recordable.stopRecording()
                self.apply(recordingState: await recordable.currentRecordingState())
            } else {
                do {
                    _ = try await recordable.startManualRecording()
                    self.apply(recordingState: await recordable.currentRecordingState())
                } catch {
                    self.logger.error("Failed to start manual recording: \(error.localizedDescription)")
                }
            }
        }
    }

    private func apply(recordingState: RecordingState) {
        isRecording = recordingState.isRecording
        isRecordingPaused = recordingState.isPaused
        if let url = recordingState.currentFileURL {
            lastSavedFileURL = url
        }
    }

    // MARK: - 60Hz Snapshot Updates

    private func update(with packet: TelemetryPacket) {
        if let packet = packet as? GT7Packet {
            self.sessionPhase = packet.sessionPhase
        }
        receivedPacketCount += 1
        if receivedPacketCount == 1 || receivedPacketCount % 600 == 0 {
            logger.info("📱 ViewModel packet checkpoint: received=\(self.receivedPacketCount), rpm=\(packet.engineRPM), speed=\(packet.speedMph)")
        }

        self.carCode = packet.carCode

        self.motion = MotionState(
            speedMph: packet.speedMph,
            speedKmh: packet.speedKmh,
            gear: packet.gear,
            suggestedGear: packet.suggestedGear
        )

        self.engine = EngineState(
            rpm: packet.engineRPM,
            maxRPM: 8500,
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