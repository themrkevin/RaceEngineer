import TelemetryKit

/// Neutral corner evidence handed to the tuning request pipeline for one recording.
public struct EvidenceBundle: Sendable, Equatable, Codable {
    public let cornerEvidence: [CornerEvidence]

    public init(cornerEvidence: [CornerEvidence]) {
        self.cornerEvidence = cornerEvidence
    }
}
