import TelemetryKit

public protocol ResponseValidator: Sendable {
    func validate(_ response: TuningResponse, against evidence: EvidenceBundle) -> Bool
}

/// Confirms every evidence reference in a response traces to a real, matching corner-evidence value.
public struct EvidenceTraceValidator: ResponseValidator {
    public init() {}

    public func validate(_ response: TuningResponse, against evidence: EvidenceBundle) -> Bool {
        let evidenceByCornerIndex = Dictionary(uniqueKeysWithValues: evidence.cornerEvidence.map { ($0.cornerIndex, $0) })

        for recommendation in response.recommendations {
            for reference in recommendation.evidenceReferences {
                guard let cornerEvidence = evidenceByCornerIndex[reference.cornerIndex],
                      let actualValue = metricValue(reference.metric, from: cornerEvidence),
                      abs(actualValue - reference.value) < 0.0001 else {
                    return false
                }
            }
        }
        return true
    }

    private func metricValue(_ metric: String, from evidence: CornerEvidence) -> Double? {
        switch metric {
        case "exitAccelerationEstimateMetersPerSecondSquared":
            return Double(evidence.exitAccelerationEstimateMetersPerSecondSquared)
        default:
            return nil
        }
    }
}
