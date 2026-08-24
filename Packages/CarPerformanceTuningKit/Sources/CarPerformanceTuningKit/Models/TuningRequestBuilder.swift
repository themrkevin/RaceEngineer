public struct TuningRequestBuilder: Sendable {
    public init() {}

    public func makeRequest(
        setupSnapshot: SettingsCatalogModel,
        evidence: EvidenceBundle,
        feedback: DriverFeedbackBundle
    ) -> TuningRequest {
        TuningRequest(setupSnapshot: setupSnapshot, evidence: evidence, feedback: feedback)
    }
}
