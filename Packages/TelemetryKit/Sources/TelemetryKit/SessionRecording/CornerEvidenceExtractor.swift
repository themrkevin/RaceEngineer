import Foundation

public enum CornerEvidenceDomainStatus: String, Sendable, Equatable, Codable {
    case ready
    case caution
    case unavailable
}

public struct CornerEvidenceDomainTags: Sendable, Equatable, Codable {
    public let rideControl: CornerEvidenceDomainStatus
    public let platformContact: CornerEvidenceDomainStatus
    public let gripUtilization: CornerEvidenceDomainStatus
    public let suspensionBehavior: CornerEvidenceDomainStatus
    public let aeroInfluence: CornerEvidenceDomainStatus

    public init(
        rideControl: CornerEvidenceDomainStatus,
        platformContact: CornerEvidenceDomainStatus,
        gripUtilization: CornerEvidenceDomainStatus,
        suspensionBehavior: CornerEvidenceDomainStatus,
        aeroInfluence: CornerEvidenceDomainStatus
    ) {
        self.rideControl = rideControl
        self.platformContact = platformContact
        self.gripUtilization = gripUtilization
        self.suspensionBehavior = suspensionBehavior
        self.aeroInfluence = aeroInfluence
    }
}

public struct CornerEvidence: Sendable, Equatable, Codable {
    public let cornerIndex: Int
    public let lapNumber: Int

    public let anchorLapTimeSeconds: TimeInterval?
    public let anchorSessionTimeSeconds: TimeInterval
    public let entryLapTimeSeconds: TimeInterval?
    public let entrySessionTimeSeconds: TimeInterval
    public let minimumSpeedLapTimeSeconds: TimeInterval?
    public let minimumSpeedSessionTimeSeconds: TimeInterval
    public let exitLapTimeSeconds: TimeInterval?
    public let exitSessionTimeSeconds: TimeInterval
    public let throttlePickupLapTimeSeconds: TimeInterval?
    public let throttlePickupSessionTimeSeconds: TimeInterval?

    public let entrySpeedMetersPerSecond: Float
    public let minimumSpeedMetersPerSecond: Float
    public let exitSpeedMetersPerSecond: Float
    public let speedRecoveryMetersPerSecond: Float
    public let peakLateralCentripetalG: Float

    public let entryGear: Int
    public let minimumSpeedGear: Int
    public let exitGear: Int

    public let entryBrake: Float
    public let exitThrottle: Float
    public let throttlePickupDelaySeconds: TimeInterval?
    public let exitAccelerationEstimateMetersPerSecondSquared: Float

    public let isPossibleCorner: Bool
    public let evidenceConfidence: Float
    public let domainTags: CornerEvidenceDomainTags
    public let dataWarnings: [String]

    public init(
        cornerIndex: Int,
        lapNumber: Int,
        anchorLapTimeSeconds: TimeInterval?,
        anchorSessionTimeSeconds: TimeInterval,
        entryLapTimeSeconds: TimeInterval?,
        entrySessionTimeSeconds: TimeInterval,
        minimumSpeedLapTimeSeconds: TimeInterval?,
        minimumSpeedSessionTimeSeconds: TimeInterval,
        exitLapTimeSeconds: TimeInterval?,
        exitSessionTimeSeconds: TimeInterval,
        throttlePickupLapTimeSeconds: TimeInterval?,
        throttlePickupSessionTimeSeconds: TimeInterval?,
        entrySpeedMetersPerSecond: Float,
        minimumSpeedMetersPerSecond: Float,
        exitSpeedMetersPerSecond: Float,
        speedRecoveryMetersPerSecond: Float,
        peakLateralCentripetalG: Float,
        entryGear: Int,
        minimumSpeedGear: Int,
        exitGear: Int,
        entryBrake: Float,
        exitThrottle: Float,
        throttlePickupDelaySeconds: TimeInterval?,
        exitAccelerationEstimateMetersPerSecondSquared: Float,
        isPossibleCorner: Bool,
        evidenceConfidence: Float,
        domainTags: CornerEvidenceDomainTags,
        dataWarnings: [String]
    ) {
        self.cornerIndex = cornerIndex
        self.lapNumber = lapNumber
        self.anchorLapTimeSeconds = anchorLapTimeSeconds
        self.anchorSessionTimeSeconds = anchorSessionTimeSeconds
        self.entryLapTimeSeconds = entryLapTimeSeconds
        self.entrySessionTimeSeconds = entrySessionTimeSeconds
        self.minimumSpeedLapTimeSeconds = minimumSpeedLapTimeSeconds
        self.minimumSpeedSessionTimeSeconds = minimumSpeedSessionTimeSeconds
        self.exitLapTimeSeconds = exitLapTimeSeconds
        self.exitSessionTimeSeconds = exitSessionTimeSeconds
        self.throttlePickupLapTimeSeconds = throttlePickupLapTimeSeconds
        self.throttlePickupSessionTimeSeconds = throttlePickupSessionTimeSeconds
        self.entrySpeedMetersPerSecond = entrySpeedMetersPerSecond
        self.minimumSpeedMetersPerSecond = minimumSpeedMetersPerSecond
        self.exitSpeedMetersPerSecond = exitSpeedMetersPerSecond
        self.speedRecoveryMetersPerSecond = speedRecoveryMetersPerSecond
        self.peakLateralCentripetalG = peakLateralCentripetalG
        self.entryGear = entryGear
        self.minimumSpeedGear = minimumSpeedGear
        self.exitGear = exitGear
        self.entryBrake = entryBrake
        self.exitThrottle = exitThrottle
        self.throttlePickupDelaySeconds = throttlePickupDelaySeconds
        self.exitAccelerationEstimateMetersPerSecondSquared = exitAccelerationEstimateMetersPerSecondSquared
        self.isPossibleCorner = isPossibleCorner
        self.evidenceConfidence = evidenceConfidence
        self.domainTags = domainTags
        self.dataWarnings = dataWarnings
    }
}

/// Builds deterministic per-corner evidence records from corner windows.
public struct CornerEvidenceExtractor: Sendable {
    public init() {}

    public func extract(
        packets: [TelemetryPacket],
        windows: [CornerPerformanceWindow],
        sampleRate: UInt16
    ) -> [CornerEvidence] {
        guard sampleRate > 0 else { return [] }

        let sampleInterval = 1.0 / Double(sampleRate)
        let packetTimes = packetTimes(packets: packets, sampleInterval: sampleInterval)

        return windows.enumerated().map { index, window in
            makeEvidence(
                cornerIndex: index,
                window: window,
                packets: packets,
                packetTimes: packetTimes,
                sampleInterval: sampleInterval
            )
        }
    }

    private func makeEvidence(
        cornerIndex: Int,
        window: CornerPerformanceWindow,
        packets: [TelemetryPacket],
        packetTimes: [TimeInterval],
        sampleInterval: TimeInterval
    ) -> CornerEvidence {
        let anchorSessionTime = window.anchorEvent.sessionTime
        let anchorLapTime = window.anchorEvent.lapTime
        let entryLapTime = lapTime(anchorLapTime: anchorLapTime, anchorSessionTime: anchorSessionTime, targetSessionTime: window.entryTime)
        let minimumLapTime = lapTime(anchorLapTime: anchorLapTime, anchorSessionTime: anchorSessionTime, targetSessionTime: window.minimumSpeedTime)
        let exitLapTime = lapTime(anchorLapTime: anchorLapTime, anchorSessionTime: anchorSessionTime, targetSessionTime: window.exitTime)
        let throttlePickupLapTime = window.throttlePickupTime.flatMap {
            lapTime(anchorLapTime: anchorLapTime, anchorSessionTime: anchorSessionTime, targetSessionTime: $0)
        }

        var warnings: [String] = []
        if anchorLapTime == nil {
            warnings.append("anchorLapTimeUnavailable")
        }

        let cornerDuration = window.exitTime - window.entryTime
        if cornerDuration <= 0 {
            warnings.append("nonPositiveCornerDuration")
        }

        let entryIndex = nearestPacketIndex(to: window.entryTime, packetTimes: packetTimes)
        let exitIndex = nearestPacketIndex(to: window.exitTime, packetTimes: packetTimes)

        let throttlePickupDelaySeconds: TimeInterval?
        if let throttleTime = window.throttlePickupTime {
            let delay = throttleTime - window.minimumSpeedTime
            if delay < 0 {
                warnings.append("throttlePickupBeforeMinimumSpeed")
            }
            throttlePickupDelaySeconds = max(0, delay)
        } else {
            throttlePickupDelaySeconds = nil
        }

        let minToExitDuration = window.exitTime - window.minimumSpeedTime
        let exitAccelerationEstimate: Float
        if minToExitDuration > 0 {
            exitAccelerationEstimate = Float(window.speedRecoveryMetersPerSecond / Float(minToExitDuration))
        } else {
            warnings.append("nonPositiveMinimumToExitDuration")
            exitAccelerationEstimate = 0
        }

        let evidenceConfidence = confidenceScore(
            hasLapTiming: anchorLapTime != nil,
            hasThrottlePickup: throttlePickupDelaySeconds != nil,
            cornerDuration: cornerDuration,
            exitAccelerationEstimate: exitAccelerationEstimate,
            isPossibleCorner: window.isPossibleCorner,
            warningCount: warnings.count
        )

        let (domainTags, domainWarnings) = domainTags(
            packets: packets,
            entryIndex: entryIndex,
            exitIndex: exitIndex,
            entrySpeedMetersPerSecond: window.entrySpeedMetersPerSecond,
            exitSpeedMetersPerSecond: window.exitSpeedMetersPerSecond
        )
        warnings.append(contentsOf: domainWarnings)

        return CornerEvidence(
            cornerIndex: cornerIndex,
            lapNumber: window.anchorEvent.lapNumber,
            anchorLapTimeSeconds: anchorLapTime,
            anchorSessionTimeSeconds: anchorSessionTime,
            entryLapTimeSeconds: entryLapTime,
            entrySessionTimeSeconds: window.entryTime,
            minimumSpeedLapTimeSeconds: minimumLapTime,
            minimumSpeedSessionTimeSeconds: window.minimumSpeedTime,
            exitLapTimeSeconds: exitLapTime,
            exitSessionTimeSeconds: window.exitTime,
            throttlePickupLapTimeSeconds: throttlePickupLapTime,
            throttlePickupSessionTimeSeconds: window.throttlePickupTime,
            entrySpeedMetersPerSecond: window.entrySpeedMetersPerSecond,
            minimumSpeedMetersPerSecond: window.minimumSpeedMetersPerSecond,
            exitSpeedMetersPerSecond: window.exitSpeedMetersPerSecond,
            speedRecoveryMetersPerSecond: window.speedRecoveryMetersPerSecond,
            peakLateralCentripetalG: window.peakLateralCentripetalG,
            entryGear: window.entryGear,
            minimumSpeedGear: window.minimumSpeedGear,
            exitGear: window.exitGear,
            entryBrake: window.entryBrake,
            exitThrottle: window.exitThrottle,
            throttlePickupDelaySeconds: throttlePickupDelaySeconds,
            exitAccelerationEstimateMetersPerSecondSquared: exitAccelerationEstimate,
            isPossibleCorner: window.isPossibleCorner,
            evidenceConfidence: evidenceConfidence,
            domainTags: domainTags,
            dataWarnings: warnings
        )
    }

    private func domainTags(
        packets: [TelemetryPacket],
        entryIndex: Int?,
        exitIndex: Int?,
        entrySpeedMetersPerSecond: Float,
        exitSpeedMetersPerSecond: Float
    ) -> (CornerEvidenceDomainTags, [String]) {
        var warnings: [String] = []

        let hasWindowPacketSlice: Bool
        if let entryIndex, let exitIndex,
           entryIndex >= 0,
           exitIndex >= entryIndex,
           exitIndex < packets.count {
            hasWindowPacketSlice = true
        } else {
            hasWindowPacketSlice = false
        }

        let rideAndSuspensionStatus: CornerEvidenceDomainStatus
        let platformContactStatus: CornerEvidenceDomainStatus
        if hasWindowPacketSlice {
            rideAndSuspensionStatus = .caution
            platformContactStatus = .caution
        } else {
            rideAndSuspensionStatus = .unavailable
            platformContactStatus = .unavailable
            warnings.append("domainSignalsUnavailable:rideAndSuspension")
        }

        // Grip proxies are currently derived from speed, throttle/brake, and corner timing.
        let gripUtilizationStatus: CornerEvidenceDomainStatus = .ready

        // Aero influence remains a proxy until richer attribution exists.
        // Without a packet slice, treat aero as unavailable regardless of speeds.
        let aeroInfluenceStatus: CornerEvidenceDomainStatus
        if hasWindowPacketSlice {
            let highSpeedContext = max(entrySpeedMetersPerSecond, exitSpeedMetersPerSecond) >= 40
            aeroInfluenceStatus = highSpeedContext ? .caution : .unavailable
            if !highSpeedContext {
                warnings.append("domainSignalsUnavailable:aeroHighSpeedContext")
            }
        } else {
            aeroInfluenceStatus = .unavailable
            warnings.append("domainSignalsUnavailable:aeroPacketSlice")
        }

        return (
            CornerEvidenceDomainTags(
                rideControl: rideAndSuspensionStatus,
                platformContact: platformContactStatus,
                gripUtilization: gripUtilizationStatus,
                suspensionBehavior: rideAndSuspensionStatus,
                aeroInfluence: aeroInfluenceStatus
            ),
            warnings
        )
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

    private func lapTime(
        anchorLapTime: TimeInterval?,
        anchorSessionTime: TimeInterval,
        targetSessionTime: TimeInterval
    ) -> TimeInterval? {
        guard let anchorLapTime else { return nil }
        return anchorLapTime + (targetSessionTime - anchorSessionTime)
    }

    private func confidenceScore(
        hasLapTiming: Bool,
        hasThrottlePickup: Bool,
        cornerDuration: TimeInterval,
        exitAccelerationEstimate: Float,
        isPossibleCorner: Bool,
        warningCount: Int
    ) -> Float {
        var score: Float = 0.35
        if isPossibleCorner { score += 0.25 }
        if hasLapTiming { score += 0.15 }
        if hasThrottlePickup { score += 0.10 }
        if cornerDuration > 0 { score += 0.10 }
        if exitAccelerationEstimate > 0 { score += 0.10 }
        score -= min(0.30, Float(warningCount) * 0.05)
        return clamp(score, min: 0, max: 1)
    }

    private func clamp(_ value: Float, min minimum: Float, max maximum: Float) -> Float {
        if value < minimum { return minimum }
        if value > maximum { return maximum }
        return value
    }
}
