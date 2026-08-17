//
//  TelemetryDisplayModels.swift
//  RaceEngineer
//
//  Created on 8/16/26.
//

import Foundation
import TelemetryKit

// MARK: - Motion State (Velocity & Gearing)

/// Immutable value-type snapshot of vehicle speed, gear, and powertrain output.
public struct MotionState: Sendable, Equatable, Hashable {
    public let speedMph: Float
    public let speedKmh: Float
    public let gear: Int
    public let suggestedGear: Int

    public init(
        speedMph: Float = 0,
        speedKmh: Float = 0,
        gear: Int = 0,
        suggestedGear: Int = 0
    ) {
        self.speedMph = speedMph
        self.speedKmh = speedKmh
        self.gear = gear
        self.suggestedGear = suggestedGear
    }

    public static let idle = MotionState()
    public static let racing = MotionState(speedMph: 142.5, speedKmh: 229.3, gear: 4, suggestedGear: 4)
    public static let shiftSuggested = MotionState(speedMph: 158.0, speedKmh: 254.2, gear: 4, suggestedGear: 5)
}

// MARK: - Engine State (RPM, Thermals & Fluids)

/// Immutable value-type snapshot of engine revs, fluid temperatures, and fuel levels.
public struct EngineState: Sendable, Equatable, Hashable {
    public let rpm: Float
    public let maxRPM: Float
    public let oilTemp: Float
    public let waterTemp: Float
    public let fuelLevel: Float
    public let fuelCapacity: Float
    public let turboBoost: Float

    public var rpmPercent: Float {
        guard maxRPM > 0 else { return 0 }
        return min(max(rpm / maxRPM, 0.0), 1.0)
    }

    public var fuelPercent: Float {
        guard fuelCapacity > 0 else { return 0 }
        return min(max(fuelLevel / fuelCapacity, 0.0), 1.0)
    }

    public var isShiftLightActive: Bool {
        rpmPercent >= 0.95
    }

    public init(
        rpm: Float = 0,
        maxRPM: Float = 8000,
        oilTemp: Float = 0,
        waterTemp: Float = 0,
        fuelLevel: Float = 0,
        fuelCapacity: Float = 100,
        turboBoost: Float = 0
    ) {
        self.rpm = rpm
        self.maxRPM = maxRPM
        self.oilTemp = oilTemp
        self.waterTemp = waterTemp
        self.fuelLevel = fuelLevel
        self.fuelCapacity = fuelCapacity
        self.turboBoost = turboBoost
    }

    public static let idle = EngineState(rpm: 950, maxRPM: 8500, oilTemp: 85.0, waterTemp: 82.0, fuelLevel: 45.0, fuelCapacity: 60.0, turboBoost: 0.0)
    public static let racing = EngineState(rpm: 6800, maxRPM: 8500, oilTemp: 102.5, waterTemp: 92.0, fuelLevel: 32.4, fuelCapacity: 60.0, turboBoost: 1.35)
    public static let shiftAlert = EngineState(rpm: 8350, maxRPM: 8500, oilTemp: 108.0, waterTemp: 96.5, fuelLevel: 28.0, fuelCapacity: 60.0, turboBoost: 1.48)
    public static let overheating = EngineState(rpm: 7200, maxRPM: 8500, oilTemp: 135.0, waterTemp: 118.0, fuelLevel: 12.0, fuelCapacity: 60.0, turboBoost: 1.20)
}

// MARK: - Driver Input State (Pedals & Steering)

/// Immutable value-type snapshot of real-time driver pedal and steering inputs (0.0 to 1.0 range).
public struct DriverInputState: Sendable, Equatable, Hashable {
    public let throttle: Float
    public let brake: Float
    public let clutch: Float
    public let steeringAngle: Float

    public init(
        throttle: Float = 0,
        brake: Float = 0,
        clutch: Float = 0,
        steeringAngle: Float = 0
    ) {
        self.throttle = min(max(throttle, 0.0), 1.0)
        self.brake = min(max(brake, 0.0), 1.0)
        self.clutch = min(max(clutch, 0.0), 1.0)
        self.steeringAngle = steeringAngle
    }

    public static let idle = DriverInputState()
    public static let fullThrottle = DriverInputState(throttle: 1.0, brake: 0.0, clutch: 0.0, steeringAngle: 0.0)
    public static let heavyBraking = DriverInputState(throttle: 0.0, brake: 0.95, clutch: 0.0, steeringAngle: -0.15)
    public static let trailBraking = DriverInputState(throttle: 0.15, brake: 0.45, clutch: 0.0, steeringAngle: 0.32)
}

// MARK: - Tire State (4 Corners)

/// Immutable value-type snapshot of 4-corner tire temperatures, pressures, and road contacts.
public struct TireState: Sendable, Equatable {
    public let surfaceTemps: TireData<Float>
    public let activeTorque: TireData<Float>
    public let suspensionTravel: TireData<Float>

    public init(
        surfaceTemps: TireData<Float> = TireData(frontLeft: 0, frontRight: 0, rearLeft: 0, rearRight: 0),
        activeTorque: TireData<Float> = TireData(frontLeft: 0, frontRight: 0, rearLeft: 0, rearRight: 0),
        suspensionTravel: TireData<Float> = TireData(frontLeft: 0, frontRight: 0, rearLeft: 0, rearRight: 0)
    ) {
        self.surfaceTemps = surfaceTemps
        self.activeTorque = activeTorque
        self.suspensionTravel = suspensionTravel
    }

    public static let cold = TireState(
        surfaceTemps: TireData(frontLeft: 22.0, frontRight: 22.0, rearLeft: 22.0, rearRight: 22.0)
    )
    public static let optimal = TireState(
        surfaceTemps: TireData(frontLeft: 84.5, frontRight: 86.2, rearLeft: 81.0, rearRight: 82.5)
    )
    public static let overheating = TireState(
        surfaceTemps: TireData(frontLeft: 112.0, frontRight: 115.5, rearLeft: 94.0, rearRight: 96.0)
    )
}

// MARK: - Lap & Timing State

/// Immutable value-type snapshot of session timing, position, and lap progression.
public struct LapTimingState: Sendable, Equatable, Hashable {
    public let currentLapNumber: Int
    public let racePosition: Int
    public let totalCars: Int
    public let currentLapTime: TimeInterval?
    public let lastLapTime: TimeInterval?
    public let bestLapTime: TimeInterval?

    public init(
        currentLapNumber: Int = 0,
        racePosition: Int = 0,
        totalCars: Int = 0,
        currentLapTime: TimeInterval? = nil,
        lastLapTime: TimeInterval? = nil,
        bestLapTime: TimeInterval? = nil
    ) {
        self.currentLapNumber = currentLapNumber
        self.racePosition = racePosition
        self.totalCars = totalCars
        self.currentLapTime = currentLapTime
        self.lastLapTime = lastLapTime
        self.bestLapTime = bestLapTime
    }

    public static let empty = LapTimingState()
    public static let racing = LapTimingState(
        currentLapNumber: 4,
        racePosition: 2,
        totalCars: 16,
        currentLapTime: 42.85,
        lastLapTime: 84.12,
        bestLapTime: 82.74
    )
}

// MARK: - Full Telemetry Snapshot

/// Complete composite snapshot aggregating domain states into a single immutable stack-allocated payload.
public struct TelemetrySnapshot: Sendable, Equatable {
    public let carCode: Int32?
    public let motion: MotionState
    public let engine: EngineState
    public let inputs: DriverInputState
    public let tires: TireState
    public let timing: LapTimingState

    public init(
        carCode: Int32? = nil,
        motion: MotionState = .idle,
        engine: EngineState = .idle,
        inputs: DriverInputState = .idle,
        tires: TireState = .cold,
        timing: LapTimingState = .empty
    ) {
        self.carCode = carCode
        self.motion = motion
        self.engine = engine
        self.inputs = inputs
        self.tires = tires
        self.timing = timing
    }

    public static let idle = TelemetrySnapshot()
    public static let racing = TelemetrySnapshot(
        carCode: 1234,
        motion: .racing,
        engine: .racing,
        inputs: .trailBraking,
        tires: .optimal,
        timing: .racing
    )
}
