import TelemetryKit

public protocol EvidenceExtractor: Sendable {
    func extractEvidence(from cornerEvidence: [CornerEvidence]) -> EvidenceBundle
}

/// POC extractor: forwards corner evidence unchanged into the evidence bundle.
public struct PassthroughEvidenceExtractor: EvidenceExtractor {
    public init() {}

    public func extractEvidence(from cornerEvidence: [CornerEvidence]) -> EvidenceBundle {
        EvidenceBundle(cornerEvidence: cornerEvidence)
    }
}
