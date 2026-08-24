/// Top-level AI response for one `TuningRequest`.
public struct TuningResponse: Sendable, Equatable, Codable {
    public let recommendations: [TuningRecommendation]

    public init(recommendations: [TuningRecommendation]) {
        self.recommendations = recommendations
    }
}
