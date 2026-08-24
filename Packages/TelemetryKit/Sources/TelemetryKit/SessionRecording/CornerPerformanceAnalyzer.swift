import Foundation

public struct CornerPerformanceWindow: Sendable, Equatable {
    public let anchorEvent: TelemetryEvent
    public let entryTime: TimeInterval
    public let entrySpeedMetersPerSecond: Float
    public let entryGear: Int
    public let entryBrake: Float
    public let minimumSpeedTime: TimeInterval
    public let minimumSpeedMetersPerSecond: Float
    public let minimumSpeedGear: Int
    public let peakLateralCentripetalG: Float
    public let throttlePickupTime: TimeInterval?
    public let exitTime: TimeInterval
    public let exitSpeedMetersPerSecond: Float
    public let exitGear: Int
    public let exitThrottle: Float
    public let speedRecoveryMetersPerSecond: Float
    public let isPossibleCorner: Bool

    public init(
        anchorEvent: TelemetryEvent,
        entryTime: TimeInterval,
        entrySpeedMetersPerSecond: Float,
        entryGear: Int,
        entryBrake: Float,
        minimumSpeedTime: TimeInterval,
        minimumSpeedMetersPerSecond: Float,
        minimumSpeedGear: Int,
        peakLateralCentripetalG: Float,
        throttlePickupTime: TimeInterval?,
        exitTime: TimeInterval,
        exitSpeedMetersPerSecond: Float,
        exitGear: Int,
        exitThrottle: Float,
        speedRecoveryMetersPerSecond: Float,
        isPossibleCorner: Bool
    ) {
        self.anchorEvent = anchorEvent
        self.entryTime = entryTime
        self.entrySpeedMetersPerSecond = entrySpeedMetersPerSecond
        self.entryGear = entryGear
        self.entryBrake = entryBrake
        self.minimumSpeedTime = minimumSpeedTime
        self.minimumSpeedMetersPerSecond = minimumSpeedMetersPerSecond
        self.minimumSpeedGear = minimumSpeedGear
        self.peakLateralCentripetalG = peakLateralCentripetalG
        self.throttlePickupTime = throttlePickupTime
        self.exitTime = exitTime
        self.exitSpeedMetersPerSecond = exitSpeedMetersPerSecond
        self.exitGear = exitGear
        self.exitThrottle = exitThrottle
        self.speedRecoveryMetersPerSecond = speedRecoveryMetersPerSecond
        self.isPossibleCorner = isPossibleCorner
    }
}

public struct CornerPerformanceAnalyzerConfiguration: Sendable, Equatable {
    public let entryContext: TimeInterval
    public let exitContext: TimeInterval
    public let throttlePickupThreshold: Float
    public let steeringDemandThreshold: Float

    public init(
        entryContext: TimeInterval = 2,
        exitContext: TimeInterval = 5,
        throttlePickupThreshold: Float = 0.2,
        steeringDemandThreshold: Float = 0.05
    ) {
        self.entryContext = entryContext
        self.exitContext = exitContext
        self.throttlePickupThreshold = throttlePickupThreshold
        self.steeringDemandThreshold = steeringDemandThreshold
    }
}

/// Builds compact corner context around possible hard-braking corner anchors.
public struct CornerPerformanceAnalyzer: Sendable {
    public let configuration: CornerPerformanceAnalyzerConfiguration

    public init(configuration: CornerPerformanceAnalyzerConfiguration = .init()) {
        self.configuration = configuration
    }

    public func analyze(
        packets: [TelemetryPacket],
        events: [TelemetryEvent],
        sampleRate: UInt16
    ) -> [CornerPerformanceWindow] {
        guard packets.count > 1, sampleRate > 0 else { return [] }

        let sampleInterval = 1.0 / Double(sampleRate)
        let packetTimes = packetTimes(packets: packets, sampleInterval: sampleInterval)
        return events
            .filter { $0.kinds.contains(.hardBraking) && !$0.kinds.contains(.fullStop) }
            .compactMap { event in
                guard let anchorIndex = nearestPacketIndex(to: event.sessionTime, packetTimes: packetTimes) else {
                    return nil
                }

                let entryIndex = max(0, anchorIndex - Int(configuration.entryContext / sampleInterval))
                let exitLimit = min(packets.count - 1, anchorIndex + Int(configuration.exitContext / sampleInterval))
                let apexRange = anchorIndex...exitLimit
                guard let apexIndex = apexRange.min(by: { packets[$0].speedMetersPerSecond < packets[$1].speedMetersPerSecond }) else {
                    return nil
                }

                let throttleIndex: Int?
                if apexIndex < exitLimit {
                    throttleIndex = (apexIndex + 1...exitLimit).first { index in
                        packets[index].throttle >= configuration.throttlePickupThreshold &&
                        packets[index - 1].throttle < configuration.throttlePickupThreshold &&
                        packets[index].speedMetersPerSecond > packets[apexIndex].speedMetersPerSecond
                    }
                } else {
                    throttleIndex = nil
                }
                let exitIndex = throttleIndex ?? exitLimit
                let peakLateralG = (apexIndex...exitIndex).map { index in
                    abs(packets[index].speedMetersPerSecond * packets[index].angularVelocity.y) / 9.80665
                }.max() ?? 0
                let steeringPresent = (entryIndex...exitIndex).contains {
                    abs(packets[$0].steeringAngle) >= configuration.steeringDemandThreshold
                }
                let brakingPresent = (entryIndex...anchorIndex).contains { packets[$0].brake > 0 }
                let entrySpeed = packets[entryIndex].speedMetersPerSecond
                let exitSpeed = packets[exitIndex].speedMetersPerSecond

                return CornerPerformanceWindow(
                    anchorEvent: event,
                    entryTime: packetTimes[entryIndex],
                    entrySpeedMetersPerSecond: entrySpeed,
                    entryGear: packets[entryIndex].gear,
                    entryBrake: packets[entryIndex].brake,
                    minimumSpeedTime: packetTimes[apexIndex],
                    minimumSpeedMetersPerSecond: packets[apexIndex].speedMetersPerSecond,
                    minimumSpeedGear: packets[apexIndex].gear,
                    peakLateralCentripetalG: peakLateralG,
                    throttlePickupTime: throttleIndex.map { packetTimes[$0] },
                    exitTime: packetTimes[exitIndex],
                    exitSpeedMetersPerSecond: exitSpeed,
                    exitGear: packets[exitIndex].gear,
                    exitThrottle: packets[exitIndex].throttle,
                    speedRecoveryMetersPerSecond: exitSpeed - packets[apexIndex].speedMetersPerSecond,
                    isPossibleCorner: steeringPresent && brakingPresent
                )
            }
    }

    private func packetTimes(packets: [TelemetryPacket], sampleInterval: TimeInterval) -> [TimeInterval] {
        guard let firstPacket = packets.first as? GT7Packet else {
            return packets.indices.map { Double($0) * sampleInterval }
        }
        return packets.map { packet in
            guard let packet = packet as? GT7Packet else { return 0 }
            return Double(packet.packetSequence - firstPacket.packetSequence) * sampleInterval
        }
    }

    private func nearestPacketIndex(to time: TimeInterval, packetTimes: [TimeInterval]) -> Int? {
        packetTimes.indices.min { lhs, rhs in
            abs(packetTimes[lhs] - time) < abs(packetTimes[rhs] - time)
        }
    }
}
