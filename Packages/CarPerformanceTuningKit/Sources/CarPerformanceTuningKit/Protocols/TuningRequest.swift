/// Combines confirmed setup, corner evidence, and driver feedback into one AI request.
public struct TuningRequest: Sendable, Equatable, Codable {
    public let setupSnapshot: SettingsCatalogModel
    public let evidence: EvidenceBundle
    public let feedback: DriverFeedbackBundle

    public init(setupSnapshot: SettingsCatalogModel, evidence: EvidenceBundle, feedback: DriverFeedbackBundle) {
        self.setupSnapshot = setupSnapshot
        self.evidence = evidence
        self.feedback = feedback
    }
}
