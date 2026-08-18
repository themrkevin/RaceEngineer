import XCTest
@testable import TelemetryKit

final class GT7PacketTests: XCTestCase {
    
    func testPacketMappingOffsetsDoNotOverlap() {
        // Assert critical session/timing offsets match protocol reference
        XCTAssertEqual(GT7PacketMapping.Kinematics.magic, 0x00)
        XCTAssertEqual(GT7PacketMapping.Kinematics.positionX, 0x04)
        XCTAssertEqual(GT7PacketMapping.Kinematics.velocityX, 0x10)
        XCTAssertEqual(GT7PacketMapping.Powertrain.engineRPM, 0x3C)
        XCTAssertEqual(GT7PacketMapping.Powertrain.carSpeed, 0x4C)
        XCTAssertEqual(GT7PacketMapping.Powertrain.waterTemp, 0x58)
        XCTAssertEqual(GT7PacketMapping.Powertrain.oilTemp, 0x5C)
        XCTAssertEqual(GT7PacketMapping.Tires.tempFrontLeft, 0x60)
        XCTAssertEqual(GT7PacketMapping.Session.packetSequence, 0x70)
        XCTAssertEqual(GT7PacketMapping.Session.currentLap, 0x74)
        XCTAssertEqual(GT7PacketMapping.Session.totalLaps, 0x76)
        XCTAssertEqual(GT7PacketMapping.Session.bestLapTime, 0x78)
        XCTAssertEqual(GT7PacketMapping.Session.lastLapTime, 0x7C)
        XCTAssertEqual(GT7PacketMapping.Session.racePosition, 0x8C)
        XCTAssertEqual(GT7PacketMapping.Session.totalCars, 0x8E)
        XCTAssertEqual(GT7PacketMapping.Inputs.gear, 0x90)
        XCTAssertEqual(GT7PacketMapping.Inputs.throttle, 0x91)
        XCTAssertEqual(GT7PacketMapping.Inputs.brake, 0x92)
        XCTAssertEqual(GT7PacketMapping.Suspension.wheelAngularVelocityFL, 0xA4)
        XCTAssertEqual(GT7PacketMapping.Suspension.tireRadiusFL, 0xB4)
        XCTAssertEqual(GT7PacketMapping.Suspension.suspensionTravelFL, 0xC4)
        XCTAssertEqual(GT7PacketMapping.Extended.carCode, 0x124)
    }

    func testPacketDecodingFromSyntheticBuffer() {
        var buffer = [UInt8](repeating: 0, count: 368)
        
        // Magic
        let magic: UInt32 = 0x47375330
        withUnsafeBytes(of: magic.littleEndian) { buffer.replaceSubrange(0..<4, with: $0) }
        
        // Speed (m/s) = 50.0 m/s (~180 km/h)
        let speedMS: Float = 50.0
        withUnsafeBytes(of: speedMS.bitPattern.littleEndian) { buffer.replaceSubrange(0x4C..<0x50, with: $0) }
        
        // Water temp = 92.5°C, Oil temp = 105.0°C
        let waterTemp: Float = 92.5
        let oilTemp: Float = 105.0
        withUnsafeBytes(of: waterTemp.bitPattern.littleEndian) { buffer.replaceSubrange(0x58..<0x5C, with: $0) }
        withUnsafeBytes(of: oilTemp.bitPattern.littleEndian) { buffer.replaceSubrange(0x5C..<0x60, with: $0) }

        // Current Lap = 3, Total Laps = 10
        let currentLap: Int16 = 3
        let totalLaps: Int16 = 10
        withUnsafeBytes(of: currentLap.littleEndian) { buffer.replaceSubrange(0x74..<0x76, with: $0) }
        withUnsafeBytes(of: totalLaps.littleEndian) { buffer.replaceSubrange(0x76..<0x78, with: $0) }
        
        // Best Lap Time = 82450 ms (1:22.450)
        let bestLapMs: Int32 = 82450
        withUnsafeBytes(of: bestLapMs.littleEndian) { buffer.replaceSubrange(0x78..<0x7C, with: $0) }

        // Position = 2, Total Cars = 16
        let racePos: Int16 = 2
        let totalCars: Int16 = 16
        withUnsafeBytes(of: racePos.littleEndian) { buffer.replaceSubrange(0x8C..<0x8E, with: $0) }
        withUnsafeBytes(of: totalCars.littleEndian) { buffer.replaceSubrange(0x8E..<0x90, with: $0) }
        
        // Gear: 4th gear (0x04) with suggested 5th gear (0x50) -> 0x54
        buffer[0x90] = 0x54
        // Throttle: 255 (1.0 full throttle)
        buffer[0x91] = 255
        // Brake: 0
        buffer[0x92] = 0
        
        // Car Code = 123456
        let carCode: Int32 = 123456
        withUnsafeBytes(of: carCode.littleEndian) { buffer.replaceSubrange(0x124..<0x128, with: $0) }

        let data = Data(buffer)
        let packet = GT7Packet(decryptedData: data)

        XCTAssertEqual(packet.magic, 0x47375330)
        XCTAssertEqual(packet.speedMetersPerSecond, 50.0, accuracy: 0.001)
        XCTAssertEqual(packet.speedKmh, 180.0, accuracy: 0.01)
        XCTAssertEqual(packet.waterTemp, 92.5, accuracy: 0.001)
        XCTAssertEqual(packet.oilTemp, 105.0, accuracy: 0.001)
        XCTAssertEqual(packet.currentLapNumber, 3)
        XCTAssertEqual(packet.totalLaps, 10)
        XCTAssertEqual(try XCTUnwrap(packet.bestLapTime), 82.45, accuracy: 0.001)
        XCTAssertEqual(packet.racePosition, 2)
        XCTAssertEqual(packet.totalCars, 16)
        XCTAssertEqual(packet.gear, 4)
        XCTAssertEqual(packet.suggestedGear, 5)
        XCTAssertEqual(packet.throttle, 1.0, accuracy: 0.001)
        XCTAssertEqual(packet.brake, 0.0, accuracy: 0.001)
        XCTAssertEqual(packet.carCode, 123456)
    }

    func testTimingSentinelsMapToNil() {
        var buffer = [UInt8](repeating: 0, count: 368)
        
        // Set lap times to -1 sentinel
        let sentinel: Int32 = -1
        withUnsafeBytes(of: sentinel.littleEndian) { buffer.replaceSubrange(0x78..<0x7C, with: $0) }
        withUnsafeBytes(of: sentinel.littleEndian) { buffer.replaceSubrange(0x7C..<0x80, with: $0) }

        let data = Data(buffer)
        let packet = GT7Packet(decryptedData: data)

        XCTAssertNil(packet.bestLapTime)
        XCTAssertNil(packet.lastLapTime)
    }
}
