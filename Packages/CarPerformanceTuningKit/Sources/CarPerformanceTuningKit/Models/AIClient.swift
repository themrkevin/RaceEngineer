import TelemetryKit

public protocol TuningAIClient: Sendable {
    func generateResponse(for request: TuningRequest) async throws -> TuningResponse
}

public typealias AIClient = TuningAIClient

/// Deterministic POC stand-in for a real AI client; encodes only the acceleration-deployment heuristic (Scenario 2).
public struct MockAIClient: TuningAIClient {
    public let highThrottleThreshold: Float
    public let accelerationRatioThreshold: Float

    public init(highThrottleThreshold: Float = 0.8, accelerationRatioThreshold: Float = 0.6) {
        self.highThrottleThreshold = highThrottleThreshold
        self.accelerationRatioThreshold = accelerationRatioThreshold
    }

    public func generateResponse(for request: TuningRequest) async throws -> TuningResponse {
        let cornerEvidence = request.evidence.cornerEvidence
        guard !cornerEvidence.isEmpty else { return TuningResponse(recommendations: []) }

        let medianAcceleration = median(of: cornerEvidence.map(\.exitAccelerationEstimateMetersPerSecondSquared))
        let flagged = cornerEvidence.filter { evidence in
            evidence.exitThrottle >= highThrottleThreshold &&
            evidence.exitAccelerationEstimateMetersPerSecondSquared < medianAcceleration * accelerationRatioThreshold
        }

        guard !flagged.isEmpty else { return TuningResponse(recommendations: []) }

        let evidenceReferences = flagged.map {
            EvidenceReference(
                cornerIndex: $0.cornerIndex,
                metric: "exitAccelerationEstimateMetersPerSecondSquared",
                value: Double($0.exitAccelerationEstimateMetersPerSecondSquared)
            )
        }

        let currentFinalGear = request.setupSnapshot.values["transmission.finalGear"]?.rawValue
        let recommendation = TuningRecommendation(
            category: .accelerationDeployment,
            confidence: min(1, Float(flagged.count) / Float(cornerEvidence.count) + 0.3),
            proposedChanges: [
                SetupChangeSuggestion(
                    settingPath: "transmission.finalGear",
                    currentValue: currentFinalGear,
                    proposedValue: "shorter final gear ratio",
                    direction: .increase
                )
            ],
            rationale: "\(flagged.count) of \(cornerEvidence.count) corner exits show high throttle with below-median acceleration.",
            evidenceReferences: evidenceReferences
        )

        return TuningResponse(recommendations: [recommendation])
    }

    private func median(of values: [Float]) -> Float {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        return sorted.count % 2 == 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
    }
}

public typealias MockTuningAIClient = MockAIClient
