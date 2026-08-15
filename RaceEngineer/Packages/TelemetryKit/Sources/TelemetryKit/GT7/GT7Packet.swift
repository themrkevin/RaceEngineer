import Foundation

/// Binary mapping for the GT7 Packet C (368-byte) telemetry packet.
public struct GT7Packet: TelemetryPacket, Sendable {
    public let data: Data
    
    public init(decryptedData: Data) {
        self.data = decryptedData
    }
    
    // MARK: - 1. Magic & Motion Vectors (0x000 - 0x03B)
    public var magic: UInt32 { data.readUInt32(at: 0x00) }
    public var position: SIMD3<Float> {
        SIMD3(data.readFloat(at: 0x04), data.readFloat(at: 0x08), data.readFloat(at: 0x0C))
    }
    public var velocity: SIMD3<Float> {
        SIMD3(data.readFloat(at: 0x10), data.readFloat(at: 0x14), data.readFloat(at: 0x18))
    }
    public var rotation: SIMD3<Float> {
        SIMD3(data.readFloat(at: 0x1C), data.readFloat(at: 0x20), data.readFloat(at: 0x24))
    }
    public var angularVelocity: SIMD3<Float> {
        SIMD3(data.readFloat(at: 0x2C), data.readFloat(at: 0x30), data.readFloat(at: 0x34))
    }
    public var bodyHeight: Float { data.readFloat(at: 0x38) }
    
    // MARK: - 2. Engine & Powertrain (0x03C - 0x04F)
    public var engineRPM: Float { data.readFloat(at: 0x3C) }
    public var fuelCapacity: Float { data.readFloat(at: 0x44) }
    public var fuelLevel: Float { data.readFloat(at: 0x48) }
    public var speedMetersPerSecond: Float { data.readFloat(at: 0x4C) }
    public var speedKmh: Float { speedMetersPerSecond * 3.6 }
    public var speedMph: Float { speedMetersPerSecond * 2.23694 }
    
    // MARK: - 3. Suspension, Wheels & Tires (0x050 - 0x08F)
    public var tireSurfaceTemps: TireData<Float> {
        TireData(
            frontLeft: data.readFloat(at: 0x50), frontRight: data.readFloat(at: 0x54),
            rearLeft: data.readFloat(at: 0x58), rearRight: data.readFloat(at: 0x5C)
        )
    }
    public var wheelAngularVelocity: TireData<Float> {
        TireData(
            frontLeft: data.readFloat(at: 0x60), frontRight: data.readFloat(at: 0x64),
            rearLeft: data.readFloat(at: 0x68), rearRight: data.readFloat(at: 0x6C)
        )
    }
    public var tireRadius: TireData<Float> {
        TireData(
            frontLeft: data.readFloat(at: 0x70), frontRight: data.readFloat(at: 0x74),
            rearLeft: data.readFloat(at: 0x78), rearRight: data.readFloat(at: 0x7C)
        )
    }
    public var suspensionTravel: TireData<Float> {
        TireData(
            frontLeft: data.readFloat(at: 0x80), frontRight: data.readFloat(at: 0x84),
            rearLeft: data.readFloat(at: 0x88), rearRight: data.readFloat(at: 0x8C)
        )
    }
    
    // MARK: - 4. Core Driver Inputs & Transmission (0x090 - 0x0A3)
    public var gear: Int { Int(data.readUInt8(at: 0x090) & 0x0F) }
    public var suggestedGear: Int { Int((data.readUInt8(at: 0x090) & 0xF0) >> 4) }
    public var throttle: Float { Float(data.readUInt8(at: 0x091)) / 255.0 }
    public var brake: Float { Float(data.readUInt8(at: 0x092)) / 255.0 }
    public var roadSurfaceFlags: UInt8 { data.readUInt8(at: 0x093) }
    public var clutchPedal: Float { data.readFloat(at: 0x094) }
    public var clutchEngagement: Float { data.readFloat(at: 0x098) }
    public var transmissionRPM: Float { data.readFloat(at: 0x09C) }
    public var turboBoost: Float { data.readFloat(at: 0x0A0) }
    
    // MARK: - 5. Timing, Laps & Session Metadata (0x0A4 - 0x127)
    public var bestLapTime: TimeInterval? {
        let millis = data.readInt32(at: 0x0A4)
        return (millis > 0 && millis != -1) ? TimeInterval(millis) / 1000.0 : nil
    }
    public var lastLapTime: TimeInterval? {
        let millis = data.readInt32(at: 0x0A8)
        return (millis > 0 && millis != -1) ? TimeInterval(millis) / 1000.0 : nil
    }
    public var currentLapNumber: Int { Int(data.readInt32(at: 0x0AC)) }
    public var racePosition: Int { Int(data.readInt16(at: 0x0B6)) }
    public var totalCars: Int { Int(data.readInt16(at: 0x0B8)) }
    
    // MARK: - 6. Extended Dynamics & Tuning Channels (0x128 - 0x170)
    public var steeringAngle: Float { data.readFloat(at: 0x128) }
    public var steeringAngularVelocity: Float { data.readFloat(at: 0x12C) }
    public var gForce: SIMD3<Float> {
        SIMD3(data.readFloat(at: 0x130), data.readFloat(at: 0x134), data.readFloat(at: 0x138))
    }
    public var activeTorque: TireData<Float> {
        TireData(
            frontLeft: data.readFloat(at: 0x140), frontRight: data.readFloat(at: 0x144),
            rearLeft: data.readFloat(at: 0x148), rearRight: data.readFloat(at: 0x14C)
        )
    }
    public var energyRecovery: Float { data.readFloat(at: 0x150) }
    public var surfaceType: TireData<Character> {
        TireData(
            frontLeft: Character(UnicodeScalar(data.readUInt8(at: 0x158))),
            frontRight: Character(UnicodeScalar(data.readUInt8(at: 0x159))),
            rearLeft: Character(UnicodeScalar(data.readUInt8(at: 0x15A))),
            rearRight: Character(UnicodeScalar(data.readUInt8(at: 0x15B)))
        )
    }
    public var currentLapTime: TimeInterval? {
        let millis = data.readInt32(at: 0x15C)
        return (millis > 0 && millis != -1) ? TimeInterval(millis) / 1000.0 : nil
    }
    public var wheelbase: Float { data.readFloat(at: 0x168) }
    
    // MARK: - Legacy Support
    public var oilTemp: Float { 0 }
    public var waterTemp: Float { 0 }
    
    public var debugDescription: String {
        "GT7PacketC(Speed: \(Int(speedMph)) MPH, Lap: \(currentLapNumber), Pos: \(racePosition)/\(totalCars))"
    }
}

// MARK: - Scoped Binary Readers

fileprivate extension Data {
    func readUInt8(at offset: Int) -> UInt8 {
        guard self.count > offset else { return 0 }
        return self[offset]
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