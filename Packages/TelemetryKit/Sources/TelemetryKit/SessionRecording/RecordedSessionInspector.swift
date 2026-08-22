import Foundation

public struct TelemetryRange: Sendable, Equatable {
    public private(set) var minimum: Float?
    public private(set) var maximum: Float?

    public init(minimum: Float? = nil, maximum: Float? = nil) {
        self.minimum = minimum
        self.maximum = maximum
    }

    fileprivate mutating func include(_ value: Float) {
        guard value.isFinite else { return }

        minimum = minimum.map { min($0, value) } ?? value
        maximum = maximum.map { max($0, value) } ?? value
    }
}

public struct RecordedSessionInspection: Sendable, Equatable {
    public let fileURL: URL
    public let header: RaceFileHeader
    public let packetCount: Int
    public let duration: TimeInterval
    public let vehicleCode: Int32?
    public let lapRange: ClosedRange<Int>?
    public let phases: Set<GT7SessionPhase>
    public let speed: TelemetryRange
    public let steeringAngle: TelemetryRange
    public let throttle: TelemetryRange
    public let brake: TelemetryRange
    public let engineRPM: TelemetryRange
    public let tireSurfaceTemperature: TelemetryRange
    public let suspensionTravel: TelemetryRange
    public let gForce: TelemetryRange
    public let invalidPacketCount: Int
    public let sequenceGapCount: Int

    public init(
        fileURL: URL,
        header: RaceFileHeader,
        packetCount: Int,
        vehicleCode: Int32?,
        lapRange: ClosedRange<Int>?,
        phases: Set<GT7SessionPhase>,
        speed: TelemetryRange,
        steeringAngle: TelemetryRange,
        throttle: TelemetryRange,
        brake: TelemetryRange,
        engineRPM: TelemetryRange,
        tireSurfaceTemperature: TelemetryRange,
        suspensionTravel: TelemetryRange,
        gForce: TelemetryRange,
        invalidPacketCount: Int,
        sequenceGapCount: Int
    ) {
        self.fileURL = fileURL
        self.header = header
        self.packetCount = packetCount
        self.duration = Double(packetCount) / Double(header.sampleRate)
        self.vehicleCode = vehicleCode
        self.lapRange = lapRange
        self.phases = phases
        self.speed = speed
        self.steeringAngle = steeringAngle
        self.throttle = throttle
        self.brake = brake
        self.engineRPM = engineRPM
        self.tireSurfaceTemperature = tireSurfaceTemperature
        self.suspensionTravel = suspensionTravel
        self.gForce = gForce
        self.invalidPacketCount = invalidPacketCount
        self.sequenceGapCount = sequenceGapCount
    }
}

public enum RecordedSessionInspectionError: Error, Equatable, Sendable {
    case fileNotFound(URL)
    case invalidHeader
    case unsupportedHeader(RaceFileHeader)
    case truncatedFrame(expected: Int, actual: Int)
}

/// Performs complete, sequential inspection of a recorded session without stream buffering.
public struct RecordedSessionInspector: Sendable {
    public init() {}

    public func inspect(fileURL: URL) throws -> RecordedSessionInspection {
        guard let handle = try? FileHandle(forReadingFrom: fileURL) else {
            throw RecordedSessionInspectionError.fileNotFound(fileURL)
        }
        defer { try? handle.close() }

        guard let headerData = try? handle.read(upToCount: RaceFileHeader.headerSize),
              headerData.count == RaceFileHeader.headerSize,
              let header = RaceFileHeader.deserialize(from: headerData) else {
            throw RecordedSessionInspectionError.invalidHeader
        }

        guard header.magic == RaceFileHeader.expectedMagic else {
            throw RecordedSessionInspectionError.invalidHeader
        }

        guard header.isValid else {
            throw RecordedSessionInspectionError.unsupportedHeader(header)
        }

        var packetCount = 0
        var vehicleCode: Int32?
        var minimumLap: Int?
        var maximumLap: Int?
        var phases = Set<GT7SessionPhase>()
        var previousSequence: Int32?
        var sequenceGapCount = 0
        var invalidPacketCount = 0
        var speed = TelemetryRange()
        var steeringAngle = TelemetryRange()
        var throttle = TelemetryRange()
        var brake = TelemetryRange()
        var engineRPM = TelemetryRange()
        var tireSurfaceTemperature = TelemetryRange()
        var suspensionTravel = TelemetryRange()
        var gForce = TelemetryRange()

        let packetSize = Int(header.packetSize)
        while true {
            guard let frame = try? handle.read(upToCount: packetSize) else { break }
            guard !frame.isEmpty else { break }
            guard frame.count == packetSize else {
                throw RecordedSessionInspectionError.truncatedFrame(
                    expected: packetSize,
                    actual: frame.count
                )
            }

            let packet = GT7Packet(decryptedData: frame)
            guard packet.magic == 0x47375330 else {
                invalidPacketCount += 1
                continue
            }

            packetCount += 1
            vehicleCode = vehicleCode ?? packet.carCode
            phases.insert(packet.sessionPhase)
            minimumLap = minimumLap.map { min($0, packet.currentLapNumber) } ?? packet.currentLapNumber
            maximumLap = maximumLap.map { max($0, packet.currentLapNumber) } ?? packet.currentLapNumber

            if let previousSequence, packet.packetSequence > previousSequence + 1 {
                sequenceGapCount += 1
            }
            previousSequence = packet.packetSequence

            speed.include(packet.speedMetersPerSecond)
            steeringAngle.include(packet.steeringAngle)
            throttle.include(packet.throttle)
            brake.include(packet.brake)
            engineRPM.include(packet.engineRPM)
            tireSurfaceTemperature.include(tireMinimum(packet.tireSurfaceTemps))
            tireSurfaceTemperature.include(tireMaximum(packet.tireSurfaceTemps))
            suspensionTravel.include(tireMinimum(packet.suspensionTravel))
            suspensionTravel.include(tireMaximum(packet.suspensionTravel))
            gForce.include(vectorMinimum(packet.gForce))
            gForce.include(vectorMaximum(packet.gForce))
        }

        let lapRange: ClosedRange<Int>?
        if let minimumLap, let maximumLap {
            lapRange = minimumLap...maximumLap
        } else {
            lapRange = nil
        }

        return RecordedSessionInspection(
            fileURL: fileURL,
            header: header,
            packetCount: packetCount,
            vehicleCode: vehicleCode,
            lapRange: lapRange,
            phases: phases,
            speed: speed,
            steeringAngle: steeringAngle,
            throttle: throttle,
            brake: brake,
            engineRPM: engineRPM,
            tireSurfaceTemperature: tireSurfaceTemperature,
            suspensionTravel: suspensionTravel,
            gForce: gForce,
            invalidPacketCount: invalidPacketCount,
            sequenceGapCount: sequenceGapCount
        )
    }
}

private func tireMinimum(_ tires: TireData<Float>) -> Float {
    min(tires.frontLeft, tires.frontRight, tires.rearLeft, tires.rearRight)
}

private func tireMaximum(_ tires: TireData<Float>) -> Float {
    max(tires.frontLeft, tires.frontRight, tires.rearLeft, tires.rearRight)
}

private func vectorMinimum(_ vector: SIMD3<Float>) -> Float {
    min(vector.x, vector.y, vector.z)
}

private func vectorMaximum(_ vector: SIMD3<Float>) -> Float {
    max(vector.x, vector.y, vector.z)
}