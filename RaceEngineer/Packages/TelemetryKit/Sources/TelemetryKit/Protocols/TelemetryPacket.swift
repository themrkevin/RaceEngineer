import Foundation

// MARK: - Generic 4-Corner Tire Container

public struct TireData<T: Sendable>: Sendable {
    public let frontLeft: T
    public let frontRight: T
    public let rearLeft: T
    public let rearRight: T

    public init(frontLeft: T, frontRight: T, rearLeft: T, rearRight: T) {
        self.frontLeft = frontLeft
        self.frontRight = frontRight
        self.rearLeft = rearLeft
        self.rearRight = rearRight
    }

    public enum Corner: CaseIterable, Sendable {
        case frontLeft, frontRight, rearLeft, rearRight
    }

    public subscript(corner: Corner) -> T {
        switch corner {
        case .frontLeft: return frontLeft
        case .frontRight: return frontRight
        case .rearLeft: return rearLeft
        case .rearRight: return rearRight
        }
    }
}

extension TireData: Equatable where T: Equatable {}
extension TireData: Hashable where T: Hashable {}

// MARK: - Normalized Telemetry Packet Protocol

/// A normalized packet format that the UI, charts, and coaching engines understand.
/// This decouples the rest of the app from game-specific binary layouts.
public protocol TelemetryPacket: Sendable {
    // Vehicle Identificaiton
    var carCode: Int32? { get }

    // 1. Magic & Motion Vectors (0x000 - 0x03B)
    var position: SIMD3<Float> { get }
    var velocity: SIMD3<Float> { get }
    var rotation: SIMD3<Float> { get } // Pitch, Yaw, Roll (radians)
    var angularVelocity: SIMD3<Float> { get }
    var bodyHeight: Float { get }
    
    // 2. Engine & Powertrain (0x03C - 0x04F)
    var engineRPM: Float { get }
    var fuelCapacity: Float { get }
    var fuelLevel: Float { get }
    var speedMetersPerSecond: Float { get }
    var speedKmh: Float { get }
    var speedMph: Float { get }
    
    // 3. Suspension, Wheels & Tires (0x050 - 0x08F)
    var tireSurfaceTemps: TireData<Float> { get }
    var wheelAngularVelocity: TireData<Float> { get }
    var tireRadius: TireData<Float> { get }
    var suspensionTravel: TireData<Float> { get }
    
    // 4. Core Driver Inputs & Transmission (0x090 - 0x0A3)
    var gear: Int { get }
    var suggestedGear: Int { get }
    var throttle: Float { get } // 0.0 - 1.0
    var brake: Float { get }    // 0.0 - 1.0
    var roadSurfaceFlags: UInt8 { get }
    var clutchPedal: Float { get }
    var clutchEngagement: Float { get }
    var transmissionRPM: Float { get }
    var turboBoost: Float { get }
    
    // 5. Timing, Laps & Session Metadata (0x0A4 - 0x127)
    var bestLapTime: TimeInterval? { get }
    var lastLapTime: TimeInterval? { get }
    var currentLapNumber: Int { get }
    var racePosition: Int { get }
    var totalCars: Int { get }
    
    // 6. Extended Dynamics & Tuning Channels (0x128 - 0x170)
    var steeringAngle: Float { get }
    var steeringAngularVelocity: Float { get }
    var gForce: SIMD3<Float> { get } // Lateral (X), Vertical (Y), Longitudinal (Z) in m/s²
    var activeTorque: TireData<Float> { get }
    var energyRecovery: Float { get }
    var surfaceType: TireData<Character> { get } // 'T' = Tarmac, 'C' = Curb, 'D' = Dirt/Grass
    var currentLapTime: TimeInterval? { get }
    var wheelbase: Float { get }
    var oilTemp: Float { get }
    var waterTemp: Float { get }
    
    var debugDescription: String { get }
}