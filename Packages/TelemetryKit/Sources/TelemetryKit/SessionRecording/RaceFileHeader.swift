import Foundation

/// Binary header structure for .race telemetry recording files (16 bytes fixed).
public struct RaceFileHeader: Sendable, Equatable {
    public static let currentVersion: UInt16 = 1
    public static let expectedMagic: UInt32 = 0x52414345 // "RACE" (ASCII)
    public static let standardPacketSize: UInt16 = 368
    public static let standardSampleRate: UInt16 = 60
    public static let headerSize: Int = 16

    public var magic: UInt32
    public var version: UInt16
    public var packetSize: UInt16
    public var sampleRate: UInt16
    public var flags: UInt16
    public var reserved: UInt32

    public init(
        magic: UInt32 = Self.expectedMagic,
        version: UInt16 = Self.currentVersion,
        packetSize: UInt16 = Self.standardPacketSize,
        sampleRate: UInt16 = Self.standardSampleRate,
        flags: UInt16 = 0,
        reserved: UInt32 = 0
    ) {
        self.magic = magic
        self.version = version
        self.packetSize = packetSize
        self.sampleRate = sampleRate
        self.flags = flags
        self.reserved = reserved
    }

    public var isValid: Bool {
        magic == Self.expectedMagic &&
        version == Self.currentVersion &&
        packetSize == Self.standardPacketSize &&
        sampleRate == Self.standardSampleRate
    }

    /// Serializes the header into 16 bytes with fixed endianness.
    public func serialize() -> Data {
        var data = Data(capacity: Self.headerSize)
        var m = magic.littleEndian
        var v = version.littleEndian
        var p = packetSize.littleEndian
        var s = sampleRate.littleEndian
        var f = flags.littleEndian
        var r = reserved.littleEndian

        data.append(Data(bytes: &m, count: 4))
        data.append(Data(bytes: &v, count: 2))
        data.append(Data(bytes: &p, count: 2))
        data.append(Data(bytes: &s, count: 2))
        data.append(Data(bytes: &f, count: 2))
        data.append(Data(bytes: &r, count: 4))
        return data
    }

    /// Deserializes a 16-byte buffer into a RaceFileHeader.
    public static func deserialize(from data: Data) -> RaceFileHeader? {
        guard data.count >= headerSize else { return nil }
        return data.withUnsafeBytes { raw in
            let m = UInt32(littleEndian: raw.loadUnaligned(fromByteOffset: 0, as: UInt32.self))
            let v = UInt16(littleEndian: raw.loadUnaligned(fromByteOffset: 4, as: UInt16.self))
            let p = UInt16(littleEndian: raw.loadUnaligned(fromByteOffset: 6, as: UInt16.self))
            let s = UInt16(littleEndian: raw.loadUnaligned(fromByteOffset: 8, as: UInt16.self))
            let f = UInt16(littleEndian: raw.loadUnaligned(fromByteOffset: 10, as: UInt16.self))
            let r = UInt32(littleEndian: raw.loadUnaligned(fromByteOffset: 12, as: UInt32.self))
            return RaceFileHeader(magic: m, version: v, packetSize: p, sampleRate: s, flags: f, reserved: r)
        }
    }
}
