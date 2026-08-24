import Foundation

public enum TelemetryEventKind: String, CaseIterable, Sendable, Equatable {
    case hardBraking
    case fullStop
    case rapidRotation
    case vehicleDisturbance
}

public struct TelemetryEvent: Sendable, Equatable {
    public let kinds: Set<TelemetryEventKind>
    public let startTime: TimeInterval
    public let peakTime: TimeInterval
    public let endTime: TimeInterval
    public let sessionTime: TimeInterval
    public let lapTime: TimeInterval?
    public let lapNumber: Int
    public let peakSpeedMetersPerSecond: Float
    public let peakYawRateRadiansPerSecond: Float
    public let peakLateralCentripetalG: Float
    public let peakWheelSpeedSpreadRatio: Float
    public let gearBefore: Int
    public let gearAtPeak: Int
    public let throttleAtPeak: Float
    public let brakeAtPeak: Float
    public let speedBeforeMetersPerSecond: Float
    public let speedAfterMetersPerSecond: Float
    public let confidence: Float

    public init(
        kinds: Set<TelemetryEventKind>,
        startTime: TimeInterval,
        peakTime: TimeInterval,
        endTime: TimeInterval,
        sessionTime: TimeInterval,
        lapTime: TimeInterval?,
        lapNumber: Int,
        peakSpeedMetersPerSecond: Float,
        peakYawRateRadiansPerSecond: Float,
        peakLateralCentripetalG: Float,
        peakWheelSpeedSpreadRatio: Float,
        gearBefore: Int,
        gearAtPeak: Int,
        throttleAtPeak: Float,
        brakeAtPeak: Float,
        speedBeforeMetersPerSecond: Float,
        speedAfterMetersPerSecond: Float,
        confidence: Float
    ) {
        self.kinds = kinds
        self.startTime = startTime
        self.peakTime = peakTime
        self.endTime = endTime
        self.sessionTime = sessionTime
        self.lapTime = lapTime
        self.lapNumber = lapNumber
        self.peakSpeedMetersPerSecond = peakSpeedMetersPerSecond
        self.peakYawRateRadiansPerSecond = peakYawRateRadiansPerSecond
        self.peakLateralCentripetalG = peakLateralCentripetalG
        self.peakWheelSpeedSpreadRatio = peakWheelSpeedSpreadRatio
        self.gearBefore = gearBefore
        self.gearAtPeak = gearAtPeak
        self.throttleAtPeak = throttleAtPeak
        self.brakeAtPeak = brakeAtPeak
        self.speedBeforeMetersPerSecond = speedBeforeMetersPerSecond
        self.speedAfterMetersPerSecond = speedAfterMetersPerSecond
        self.confidence = confidence
    }
}

public struct TelemetryEventDetectorConfiguration: Sendable, Equatable {
    public let hardBrakeInputThreshold: Float
    public let hardBrakeSpeedDropPerSample: Float
    public let fullStopSpeedThreshold: Float
    public let rapidRotationYawRateThreshold: Float
    public let rapidRotationYawChangePerSample: Float
    public let disturbanceSpeedDropPerSample: Float
    public let groupingInterval: TimeInterval

    public init(
        hardBrakeInputThreshold: Float = 0.8,
        hardBrakeSpeedDropPerSample: Float = 0.15,
        fullStopSpeedThreshold: Float = 1.0,
        rapidRotationYawRateThreshold: Float = 1.5,
        rapidRotationYawChangePerSample: Float = 0.2,
        disturbanceSpeedDropPerSample: Float = 0.5,
        groupingInterval: TimeInterval = 0.5
    ) {
        self.hardBrakeInputThreshold = hardBrakeInputThreshold
        self.hardBrakeSpeedDropPerSample = hardBrakeSpeedDropPerSample
        self.fullStopSpeedThreshold = fullStopSpeedThreshold
        self.rapidRotationYawRateThreshold = rapidRotationYawRateThreshold
        self.rapidRotationYawChangePerSample = rapidRotationYawChangePerSample
        self.disturbanceSpeedDropPerSample = disturbanceSpeedDropPerSample
        self.groupingInterval = groupingInterval
    }
}

/// Detects generic candidate events from a complete, ordered telemetry sequence.
/// It deliberately reports telemetry behavior rather than tuning diagnoses.
public struct TelemetryEventDetector: Sendable {
    public let configuration: TelemetryEventDetectorConfiguration

    public init(configuration: TelemetryEventDetectorConfiguration = .init()) {
        self.configuration = configuration
    }

    public func detect(
        packets: [TelemetryPacket],
        sampleRate: UInt16
    ) -> [TelemetryEvent] {
        guard packets.count > 1, sampleRate > 0 else { return [] }

        let sampleInterval = 1.0 / Double(sampleRate)
        var candidates: [Candidate] = []
        var observedLapStartTimes: [Int: TimeInterval] = [:]
        var previousLapNumber: Int?
        var recordingStartSequence: Int32?

        if let firstPacket = packets.first as? GT7Packet {
            previousLapNumber = firstPacket.currentLapNumber
            recordingStartSequence = firstPacket.packetSequence
        }

        for index in 1..<packets.count {
            let previous = packets[index - 1]
            let current = packets[index]
            guard let previousPacket = previous as? GT7Packet,
                  let currentPacket = current as? GT7Packet,
                  currentPacket.packetSequence == previousPacket.packetSequence + 1 else {
                continue
            }

            let speedDrop = previousPacket.speedMetersPerSecond - currentPacket.speedMetersPerSecond
            let yawChange = abs(currentPacket.angularVelocity.y - previousPacket.angularVelocity.y)
            let yawRate = abs(currentPacket.angularVelocity.y)
            let lateralG = abs(currentPacket.speedMetersPerSecond * currentPacket.angularVelocity.y) / 9.80665
            let wheelSpeedSpreadRatio = wheelSpeedSpreadRatio(currentPacket)
            recordingStartSequence = recordingStartSequence ?? previousPacket.packetSequence
            let elapsedTime = Double(currentPacket.packetSequence - (recordingStartSequence ?? currentPacket.packetSequence)) * sampleInterval
            if let previousLapNumber, currentPacket.currentLapNumber != previousLapNumber {
                observedLapStartTimes[currentPacket.currentLapNumber] = elapsedTime
            }
            previousLapNumber = currentPacket.currentLapNumber
            var kinds = Set<TelemetryEventKind>()

            if currentPacket.brake >= configuration.hardBrakeInputThreshold,
               speedDrop >= configuration.hardBrakeSpeedDropPerSample {
                kinds.insert(.hardBraking)
            }

            if currentPacket.speedMetersPerSecond <= configuration.fullStopSpeedThreshold,
               previousPacket.speedMetersPerSecond > configuration.fullStopSpeedThreshold {
                kinds.insert(.fullStop)
            }

            if yawRate >= configuration.rapidRotationYawRateThreshold ||
                yawChange >= configuration.rapidRotationYawChangePerSample {
                kinds.insert(.rapidRotation)
            }

            if speedDrop >= configuration.disturbanceSpeedDropPerSample &&
                (yawChange >= configuration.rapidRotationYawChangePerSample || yawRate >= configuration.rapidRotationYawRateThreshold) {
                kinds.insert(.vehicleDisturbance)
            }

            guard !kinds.isEmpty else { continue }

            let confidence = confidence(for: kinds, speedDrop: speedDrop, lateralG: lateralG)
            candidates.append(Candidate(
                kinds: kinds,
                packetIndex: index,
                elapsedTime: elapsedTime,
                lapNumber: currentPacket.currentLapNumber,
                speedMetersPerSecond: currentPacket.speedMetersPerSecond,
                yawRateRadiansPerSecond: currentPacket.angularVelocity.y,
                lateralCentripetalG: lateralG,
                speedBeforeMetersPerSecond: previousPacket.speedMetersPerSecond,
                confidence: confidence,
                sessionTime: elapsedTime,
                lapTime: observedLapStartTimes[currentPacket.currentLapNumber].map { elapsedTime - $0 },
                wheelSpeedSpreadRatio: wheelSpeedSpreadRatio,
                gearBefore: previousPacket.gear,
                gearAtPeak: currentPacket.gear,
                throttleAtPeak: currentPacket.throttle,
                brakeAtPeak: currentPacket.brake
            ))
        }

        return group(candidates: candidates, sampleInterval: sampleInterval)
    }

    private func group(candidates: [Candidate], sampleInterval: TimeInterval) -> [TelemetryEvent] {
        guard let first = candidates.first else { return [] }

        var events: [TelemetryEvent] = []
        var currentGroup = [first]

        for candidate in candidates.dropFirst() {
            let timeSincePrevious = candidate.elapsedTime - (currentGroup.last?.elapsedTime ?? candidate.elapsedTime)
            if timeSincePrevious <= configuration.groupingInterval {
                currentGroup.append(candidate)
                continue
            }

            events.append(makeEvent(from: currentGroup, sampleInterval: sampleInterval))
            currentGroup = [candidate]
        }

        events.append(makeEvent(from: currentGroup, sampleInterval: sampleInterval))
        return events
    }

    private func makeEvent(from candidates: [Candidate], sampleInterval: TimeInterval) -> TelemetryEvent {
        let peak = candidates.max { lhs, rhs in
            lhs.confidence < rhs.confidence
        } ?? candidates[0]
        let kinds = candidates.reduce(into: Set<TelemetryEventKind>()) { result, candidate in
            result.formUnion(candidate.kinds)
        }
        let startTime = max(0, candidates[0].elapsedTime - sampleInterval)
        let endTime = candidates.last?.elapsedTime ?? peak.elapsedTime
        let confidence = min(1, candidates.map(\.confidence).max() ?? 0)
        let peakWheelSpeedSpread = candidates.max { lhs, rhs in
            lhs.wheelSpeedSpreadRatio < rhs.wheelSpeedSpreadRatio
        } ?? peak

        return TelemetryEvent(
            kinds: kinds,
            startTime: startTime,
            peakTime: peak.elapsedTime,
            endTime: endTime,
            sessionTime: peak.sessionTime,
            lapTime: peak.lapTime,
            lapNumber: peak.lapNumber,
            peakSpeedMetersPerSecond: peak.speedMetersPerSecond,
            peakYawRateRadiansPerSecond: peak.yawRateRadiansPerSecond,
            peakLateralCentripetalG: peak.lateralCentripetalG,
            peakWheelSpeedSpreadRatio: peakWheelSpeedSpread.wheelSpeedSpreadRatio,
            gearBefore: peak.gearBefore,
            gearAtPeak: peak.gearAtPeak,
            throttleAtPeak: peak.throttleAtPeak,
            brakeAtPeak: peak.brakeAtPeak,
            speedBeforeMetersPerSecond: candidates[0].speedBeforeMetersPerSecond,
            speedAfterMetersPerSecond: candidates.last?.speedMetersPerSecond ?? peak.speedMetersPerSecond,
            confidence: confidence
        )
    }

    private func confidence(for kinds: Set<TelemetryEventKind>, speedDrop: Float, lateralG: Float) -> Float {
        var score: Float = 0.35
        score += Float(kinds.count) * 0.15
        score += min(0.25, speedDrop / 4)
        score += min(0.25, lateralG / 4)
        return min(1, score)
    }

    private struct Candidate: Sendable {
        let kinds: Set<TelemetryEventKind>
        let packetIndex: Int
        let elapsedTime: TimeInterval
        let lapNumber: Int
        let speedMetersPerSecond: Float
        let yawRateRadiansPerSecond: Float
        let lateralCentripetalG: Float
        let speedBeforeMetersPerSecond: Float
        let confidence: Float
        let sessionTime: TimeInterval
        let lapTime: TimeInterval?
        let wheelSpeedSpreadRatio: Float
        let gearBefore: Int
        let gearAtPeak: Int
        let throttleAtPeak: Float
        let brakeAtPeak: Float
    }

    private func wheelSpeedSpreadRatio(_ packet: GT7Packet) -> Float {
        let wheelSpeeds = [
            packet.wheelAngularVelocity.frontLeft * packet.tireRadius.frontLeft,
            packet.wheelAngularVelocity.frontRight * packet.tireRadius.frontRight,
            packet.wheelAngularVelocity.rearLeft * packet.tireRadius.rearLeft,
            packet.wheelAngularVelocity.rearRight * packet.tireRadius.rearRight
        ]
        let validWheelSpeeds = wheelSpeeds.filter(\.isFinite).map(abs)
        guard let minimum = validWheelSpeeds.min(),
              let maximum = validWheelSpeeds.max(),
              maximum > 0 else { return 0 }
        return (maximum - minimum) / maximum
    }
}