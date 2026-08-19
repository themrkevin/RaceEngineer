import Foundation

/// Emits simulated telemetry data for testing the UI, charts, and agents without a PS5.
public actor MockTelemetryProvider: TelemetryProvider {
    private var timerTask: Task<Void, Never>?
    private let continuation: (stream: AsyncStream<TelemetryPacket>, continuation: AsyncStream<TelemetryPacket>.Continuation)

    public init() {
        self.continuation = AsyncStream.makeStream(of: TelemetryPacket.self, bufferingPolicy: .bufferingNewest(5))
    }
    
    nonisolated public func telemetryStream() -> AsyncStream<TelemetryPacket> {
        return continuation.stream
    }

    nonisolated public func recordingStateStream() -> AsyncStream<RecordingState> {
        AsyncStream { continuation in
            continuation.yield(.idle)
            continuation.finish()
        }
    }

    public func setAutoRecordingEnabled(_ enabled: Bool) async {}

    public func startManualRecording() async throws -> URL {
        throw NSError(
            domain: "com.raceengineer.MockTelemetryProvider",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Recording is not supported in mock mode."]
        )
    }

    public func stopRecording() async {}
    
    public func start(ipAddress: String) async throws {
        stop()
        
        timerTask = Task {
            var rpm: Float = 1000.0
            var speedKmh: Float = 0.0
            var counter: Float = 0.0
            
            while !Task.isCancelled {
                counter += 0.05
                
                // Simulate driving dynamics & gear shifts
                rpm += 150
                if rpm > 8500 { rpm = 2500 }
                
                speedKmh = (rpm / 8500.0) * 280.0
                
                // Oscillate inputs and steering for visual feedback
                let throttle = 0.8 + sin(counter) * 0.2
                let brake = 0.1 + cos(counter) * 0.1
                let clutch = abs(sin(counter * 0.5)) * 0.1
                let steer = sin(counter * 0.3) * 0.35 // Oscillating steering angle (radians)
                
                let packet = MockPacket(
                    speedKmh: speedKmh,
                    engineRPM: rpm,
                    throttle: Float(throttle),
                    brake: Float(brake),
                    clutch: Float(clutch),
                    steeringAngle: Float(steer)
                )
                
                continuation.continuation.yield(packet)
                
                try? await Task.sleep(for: .milliseconds(16)) // ~60Hz
            }
        }
    }
    
    public func stop() {
        timerTask?.cancel()
        timerTask = nil
    }
}

// MARK: - Mock Packet Implementation

public struct MockPacket: TelemetryPacket, Sendable {
    // Vehicle Identification
    public var carCode: Int32? = 12345

    // 1. Magic & Motion Vectors
    public var position = SIMD3<Float>(0, 0, 0)
    public var velocity = SIMD3<Float>(0, 0, 0)
    public var rotation = SIMD3<Float>(0, 0, 0)
    public var angularVelocity = SIMD3<Float>(0, 0, 0)
    public var bodyHeight: Float = 0.05

    // 2. Engine & Powertrain
    public let speedKmh: Float
    public var speedMph: Float { speedKmh * 0.621371 }
    public var speedMetersPerSecond: Float { speedKmh / 3.6 }
    public let engineRPM: Float
    public var fuelLevel: Float = 34.2
    public var fuelCapacity: Float = 100.0

    // 3. Suspension & Tires
    public var tireSurfaceTemps = TireData<Float>(frontLeft: 85.5, frontRight: 86.2, rearLeft: 82.1, rearRight: 81.9)
    public var wheelAngularVelocity = TireData<Float>(frontLeft: 0, frontRight: 0, rearLeft: 0, rearRight: 0)
    public var tireRadius = TireData<Float>(frontLeft: 0.3, frontRight: 0.3, rearLeft: 0.3, rearRight: 0.3)
    public var suspensionTravel = TireData<Float>(frontLeft: 0, frontRight: 0, rearLeft: 0, rearRight: 0)

    // 4. Core Driver Inputs
    public var gear: Int = 4
    public var suggestedGear: Int = 3
    public let throttle: Float
    public let brake: Float
    public var roadSurfaceFlags: UInt8 = 0
    public let clutchPedal: Float
    public var clutchEngagement: Float = 0.0
    public var transmissionRPM: Float = 4000
    public var turboBoost: Float = 1.2

    // 5. Timing & Session
    public var bestLapTime: TimeInterval? = 82.5
    public var lastLapTime: TimeInterval? = 84.2
    public var currentLapNumber: Int = 5
    public var racePosition: Int = 2
    public var totalCars: Int = 20

    // 6. Extended Dynamics & Tuning Channels
    public let steeringAngle: Float
    public var steeringAngularVelocity: Float = 0.0
    public var gForce = SIMD3<Float>(0, 1, 0)
    public var activeTorque = TireData<Float>(frontLeft: 0, frontRight: 0, rearLeft: 0, rearRight: 0)
    public var energyRecovery: Float = 0.0
    public var surfaceType = TireData<Character>(frontLeft: "T", frontRight: "T", rearLeft: "T", rearRight: "T")
    public var currentLapTime: TimeInterval? = 84.2
    public var wheelbase: Float = 2.5
    
    // Legacy support
    public var oilTemp: Float = 102.4
    public var waterTemp: Float = 94.1
    public var debugDescription: String { "MockPacket(\(Int(speedMph)) MPH)" }

    public init(
        carCode: Int32? = 12345,
        speedKmh: Float,
        engineRPM: Float,
        throttle: Float,
        brake: Float,
        clutch: Float,
        steeringAngle: Float = 0.0
    ) {
        self.carCode = carCode
        self.speedKmh = speedKmh
        self.engineRPM = engineRPM
        self.throttle = throttle
        self.brake = brake
        self.clutchPedal = clutch
        self.steeringAngle = steeringAngle
    }
}