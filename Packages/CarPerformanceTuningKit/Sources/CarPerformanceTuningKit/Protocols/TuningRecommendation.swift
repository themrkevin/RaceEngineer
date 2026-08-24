public enum TuningCategory: String, Sendable, Equatable, CaseIterable, Codable {
    case accelerationDeployment
    case gearingFeel
    case cornerBalance
}

/// Points a recommendation back to the exact corner evidence value it is based on.
public struct EvidenceReference: Sendable, Equatable, Codable {
    public let cornerIndex: Int
    public let metric: String
    public let value: Double

    public init(cornerIndex: Int, metric: String, value: Double) {
        self.cornerIndex = cornerIndex
        self.metric = metric
        self.value = value
    }
}

public struct SetupChangeSuggestion: Sendable, Equatable, Codable {
    public let settingPath: String
    public let currentValue: String?
    public let proposedValue: String
    public let direction: ChangeDirection

    public init(settingPath: String, currentValue: String?, proposedValue: String, direction: ChangeDirection) {
        self.settingPath = settingPath
        self.currentValue = currentValue
        self.proposedValue = proposedValue
        self.direction = direction
    }
}

/// One diagnosed issue with proposed changes, traceable to specific corner evidence.
public struct TuningRecommendation: Sendable, Equatable, Codable {
    public let category: TuningCategory
    public let confidence: Float
    public let proposedChanges: [SetupChangeSuggestion]
    public let rationale: String
    public let evidenceReferences: [EvidenceReference]

    public init(
        category: TuningCategory,
        confidence: Float,
        proposedChanges: [SetupChangeSuggestion],
        rationale: String,
        evidenceReferences: [EvidenceReference]
    ) {
        self.category = category
        self.confidence = confidence
        self.proposedChanges = proposedChanges
        self.rationale = rationale
        self.evidenceReferences = evidenceReferences
    }
}
