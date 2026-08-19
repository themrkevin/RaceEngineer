import Foundation

/// Binary mapping for the GT7 Packet C (368-byte / 396-byte) telemetry packet.
/// Decodes and normalizes raw bytes into an immutable, pre-parsed value struct.
public struct GT7Packet: TelemetryPacket, Sendable {
    
    // MARK: - Pre-parsed Stored Properties
    
    // Vehicle Identification
    public let carCode: Int32?
    public let magic: UInt32

    // 1. Motion Vectors & Kinematics
    public let position: SIMD3<Float>
    public let velocity: SIMD3<Float>
    public let rotation: SIMD3<Float>
    public let angularVelocity: SIMD3<Float>
    public let bodyHeight: Float
    
    // 2. Engine & Powertrain
    public let engineRPM: Float
    public let fuelCapacity: Float
    public let fuelLevel: Float
    public let speedMetersPerSecond: Float
    public let speedKmh: Float
    public let speedMph: Float
    public let turboBoost: Float
    public let oilPressure: Float
    public let waterTemp: Float
    public let oilTemp: Float
    
    // 3. Suspension, Wheels & Tires
    public let tireSurfaceTemps: TireData<Float>
    public let wheelAngularVelocity: TireData<Float>
    public let tireRadius: TireData<Float>
    public let suspensionTravel: TireData<Float>
    
    // 4. Driver Inputs & Transmission
    public let gear: Int
    public let suggestedGear: Int
    public let throttle: Float
    public let brake: Float
    public let roadSurfaceFlags: UInt8
    public let clutchPedal: Float
    public let clutchEngagement: Float
    public let transmissionRPM: Float
    
    // 5. Sequence, Timing & Session Metadata
    public let packetSequence: Int32
    public let currentLapNumber: Int
    public let totalLaps: Int
    public let bestLapTime: TimeInterval?
    public let lastLapTime: TimeInterval?
    public let racePosition: Int
    public let totalCars: Int
    public let currentLapTime: TimeInterval?
    public let sessionFlags: GT7SessionFlags
    public var sessionPhase: GT7SessionPhase { sessionFlags.phase }
    public var isCarOnTrack: Bool { sessionFlags.isCarOnTrack }
    public var isLoading: Bool { sessionFlags.isLoading }
    public let isGamePaused: Bool
    public let inPitLane: Bool
    public let rawSessionFlags: UInt16
    
    // 6. Extended Dynamics & Tuning Channels
    public let steeringAngle: Float
    public let steeringAngularVelocity: Float
    public let gForce: SIMD3<Float>
    public let activeTorque: TireData<Float>
    public let energyRecovery: Float
    public let surfaceType: TireData<Character>
    public let wheelbase: Float
    
    public var debugDescription: String {
        "GT7Packet(Speed: \(Int(speedMph)) MPH, RPM: \(Int(engineRPM)), Lap: \(currentLapNumber), Pos: \(racePosition)/\(totalCars), Paused: \(isGamePaused))"
    }

    // MARK: - Initializer (Single-Pass Ingress Parser)
    
    public init(decryptedData data: Data) {
        guard data.count >= 0x15C else {
            self.carCode = nil
            self.magic = 0
            self.position = .zero
            self.velocity = .zero
            self.rotation = .zero
            self.angularVelocity = .zero
            self.bodyHeight = 0
            self.engineRPM = 0
            self.fuelCapacity = 0
            self.fuelLevel = 0
            self.speedMetersPerSecond = 0
            self.speedKmh = 0
            self.speedMph = 0
            self.turboBoost = 0
            self.oilPressure = 0
            self.waterTemp = 0
            self.oilTemp = 0
            self.tireSurfaceTemps = TireData(frontLeft: 0, frontRight: 0, rearLeft: 0, rearRight: 0)
            self.wheelAngularVelocity = TireData(frontLeft: 0, frontRight: 0, rearLeft: 0, rearRight: 0)
            self.tireRadius = TireData(frontLeft: 0, frontRight: 0, rearLeft: 0, rearRight: 0)
            self.suspensionTravel = TireData(frontLeft: 0, frontRight: 0, rearLeft: 0, rearRight: 0)
            self.gear = 0
            self.suggestedGear = 0
            self.throttle = 0
            self.brake = 0
            self.roadSurfaceFlags = 0
            self.clutchPedal = 0
            self.clutchEngagement = 0
            self.transmissionRPM = 0
            self.packetSequence = 0
            self.currentLapNumber = 0
            self.totalLaps = 0
            self.bestLapTime = nil
            self.lastLapTime = nil
            self.racePosition = 0
            self.totalCars = 0
            self.currentLapTime = nil
            self.sessionFlags = GT7SessionFlags(rawValue: 0)
            self.isGamePaused = false
            self.inPitLane = false
            self.rawSessionFlags = 0
            self.steeringAngle = 0
            self.steeringAngularVelocity = 0
            self.gForce = .zero
            self.activeTorque = TireData(frontLeft: 0, frontRight: 0, rearLeft: 0, rearRight: 0)
            self.energyRecovery = 0
            self.surfaceType = TireData(frontLeft: "T", frontRight: "T", rearLeft: "T", rearRight: "T")
            self.wheelbase = 0
            return
        }

        // 1. Validation & Kinematics
        self.magic = data.readUInt32(at: GT7PacketMapping.Kinematics.magic)
        self.position = SIMD3(
            data.readFloat(at: GT7PacketMapping.Kinematics.positionX),
            data.readFloat(at: GT7PacketMapping.Kinematics.positionY),
            data.readFloat(at: GT7PacketMapping.Kinematics.positionZ)
        )
        self.velocity = SIMD3(
            data.readFloat(at: GT7PacketMapping.Kinematics.velocityX),
            data.readFloat(at: GT7PacketMapping.Kinematics.velocityY),
            data.readFloat(at: GT7PacketMapping.Kinematics.velocityZ)
        )
        self.rotation = SIMD3(
            data.readFloat(at: GT7PacketMapping.Kinematics.pitch),
            data.readFloat(at: GT7PacketMapping.Kinematics.yaw),
            data.readFloat(at: GT7PacketMapping.Kinematics.roll)
        )
        self.angularVelocity = SIMD3(
            data.readFloat(at: GT7PacketMapping.Kinematics.angularVelocityX),
            data.readFloat(at: GT7PacketMapping.Kinematics.angularVelocityY),
            data.readFloat(at: GT7PacketMapping.Kinematics.angularVelocityZ)
        )
        self.bodyHeight = data.readFloat(at: GT7PacketMapping.Kinematics.bodyHeight)

        // 2. Powertrain & Fluids
        self.engineRPM = data.readFloat(at: GT7PacketMapping.Powertrain.engineRPM)
        self.fuelCapacity = data.readFloat(at: GT7PacketMapping.Powertrain.fuelCapacity)
        self.fuelLevel = data.readFloat(at: GT7PacketMapping.Powertrain.fuelLevel)
        let speedMS = data.readFloat(at: GT7PacketMapping.Powertrain.carSpeed)
        self.speedMetersPerSecond = speedMS
        self.speedKmh = speedMS * 3.6
        self.speedMph = speedMS * 2.23694
        self.turboBoost = data.readFloat(at: GT7PacketMapping.Powertrain.turboBoost)
        self.oilPressure = data.readFloat(at: GT7PacketMapping.Powertrain.oilPressure)
        self.waterTemp = data.readFloat(at: GT7PacketMapping.Powertrain.waterTemp)
        self.oilTemp = data.readFloat(at: GT7PacketMapping.Powertrain.oilTemp)

        // 3. Tires & Suspension
        self.tireSurfaceTemps = TireData(
            frontLeft: data.readFloat(at: GT7PacketMapping.Tires.tempFrontLeft),
            frontRight: data.readFloat(at: GT7PacketMapping.Tires.tempFrontRight),
            rearLeft: data.readFloat(at: GT7PacketMapping.Tires.tempRearLeft),
            rearRight: data.readFloat(at: GT7PacketMapping.Tires.tempRearRight)
        )
        self.wheelAngularVelocity = TireData(
            frontLeft: data.readFloat(at: GT7PacketMapping.Suspension.wheelAngularVelocityFL),
            frontRight: data.readFloat(at: GT7PacketMapping.Suspension.wheelAngularVelocityFR),
            rearLeft: data.readFloat(at: GT7PacketMapping.Suspension.wheelAngularVelocityRL),
            rearRight: data.readFloat(at: GT7PacketMapping.Suspension.wheelAngularVelocityRR)
        )
        self.tireRadius = TireData(
            frontLeft: data.readFloat(at: GT7PacketMapping.Suspension.tireRadiusFL),
            frontRight: data.readFloat(at: GT7PacketMapping.Suspension.tireRadiusFR),
            rearLeft: data.readFloat(at: GT7PacketMapping.Suspension.tireRadiusRL),
            rearRight: data.readFloat(at: GT7PacketMapping.Suspension.tireRadiusRR)
        )
        self.suspensionTravel = TireData(
            frontLeft: data.readFloat(at: GT7PacketMapping.Suspension.suspensionTravelFL),
            frontRight: data.readFloat(at: GT7PacketMapping.Suspension.suspensionTravelFR),
            rearLeft: data.readFloat(at: GT7PacketMapping.Suspension.suspensionTravelRL),
            rearRight: data.readFloat(at: GT7PacketMapping.Suspension.suspensionTravelRR)
        )

        // 4. Driver Inputs & Transmission
        let rawGear = data.readUInt8(at: GT7PacketMapping.Inputs.gear)
        self.gear = Int(rawGear & 0x0F)
        self.suggestedGear = Int((rawGear & 0xF0) >> 4)
        self.throttle = Float(data.readUInt8(at: GT7PacketMapping.Inputs.throttle)) / 255.0
        self.brake = Float(data.readUInt8(at: GT7PacketMapping.Inputs.brake)) / 255.0
        self.roadSurfaceFlags = data.readUInt8(at: GT7PacketMapping.Inputs.roadSurfaceFlags)
        self.clutchPedal = 0
        self.clutchEngagement = 0
        self.transmissionRPM = 0

        // 5. Sequence, Timing & Session Metadata
        self.packetSequence = data.readInt32(at: GT7PacketMapping.Session.packetSequence)
        let rawLap = Int(data.readInt16(at: GT7PacketMapping.Session.currentLap))
        self.currentLapNumber = (rawLap > 0 && rawLap < 1000) ? rawLap : 0

        let rawTotalLaps = Int(data.readInt16(at: GT7PacketMapping.Session.totalLaps))
        self.totalLaps = (rawTotalLaps > 0 && rawTotalLaps < 1000) ? rawTotalLaps : 0

        let bestMillis = data.readInt32(at: GT7PacketMapping.Session.bestLapTime)
        self.bestLapTime = (bestMillis > 0 && bestMillis != -1) ? TimeInterval(bestMillis) / 1000.0 : nil

        let lastMillis = data.readInt32(at: GT7PacketMapping.Session.lastLapTime)
        self.lastLapTime = (lastMillis > 0 && lastMillis != -1) ? TimeInterval(lastMillis) / 1000.0 : nil

        self.racePosition = max(0, Int(data.readInt16(at: GT7PacketMapping.Session.racePosition)))
        // 0x8E is currently treated as session flags. The total-car offset is
        // not verified independently and must not be derived from this word.
        self.totalCars = 0
        self.currentLapTime = nil

        // Session flags (offset 0x8E - UInt16)
        let flags = data.readUInt16(at: GT7PacketMapping.Session.sessionFlags)
        self.sessionFlags = GT7SessionFlags(rawValue: flags)
        self.rawSessionFlags = flags
        self.isGamePaused = self.sessionFlags.isGamePaused
        self.inPitLane = false

        // 6. Extended Channels
        let rawCarCode = data.readInt32(at: GT7PacketMapping.Extended.carCode)
        self.carCode = (rawCarCode > 0 && rawCarCode != -1) ? rawCarCode : nil
        self.steeringAngle = data.readFloat(at: GT7PacketMapping.Extended.wheelSteeringAngleFL)
        self.steeringAngularVelocity = 0
        self.gForce = .zero
        self.activeTorque = TireData(frontLeft: 0, frontRight: 0, rearLeft: 0, rearRight: 0)
        self.energyRecovery = 0
        self.surfaceType = TireData(
            frontLeft: Character(UnicodeScalar(data.readUInt8(at: GT7PacketMapping.Extended.surfaceTypeFL))),
            frontRight: Character(UnicodeScalar(data.readUInt8(at: GT7PacketMapping.Extended.surfaceTypeFR))),
            rearLeft: Character(UnicodeScalar(data.readUInt8(at: GT7PacketMapping.Extended.surfaceTypeRL))),
            rearRight: Character(UnicodeScalar(data.readUInt8(at: GT7PacketMapping.Extended.surfaceTypeRR)))
        )
        self.wheelbase = data.readFloat(at: GT7PacketMapping.Extended.wheelbase)
    }
}

// MARK: - Scoped Binary Readers

fileprivate extension Data {
    func readUInt8(at offset: Int) -> UInt8 {
        guard self.count > offset else { return 0 }
        return self[offset]
    }

    func readUInt16(at offset: Int) -> UInt16 {
        guard self.count >= offset + 2 else { return 0 }
        return self.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt16.self) }
    }
    
    func readFloat(at offset: Int) -> Float {
        guard self.count >= offset + 4 else { return 0 }
        return self.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: Float.self) }
    }
    
    func readInt32(at offset: Int) -> Int32 {
        guard self.count >= offset + 4 else { return 0 }
        return self.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: Int32.self) }
    }
    
    func readInt16(at offset: Int) -> Int16 {
        guard self.count >= offset + 2 else { return 0 }
        return self.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: Int16.self) }
    }
    
    func readUInt32(at offset: Int) -> UInt32 {
        guard self.count >= offset + 4 else { return 0 }
        return self.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self) }
    }
}