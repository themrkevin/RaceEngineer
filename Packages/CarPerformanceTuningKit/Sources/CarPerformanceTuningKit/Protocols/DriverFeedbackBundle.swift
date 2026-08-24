/// Free-form driver feedback text passed into a tuning request.
public struct DriverFeedbackBundle: Sendable, Equatable, Codable {
    public let feedbackText: String

    public init(feedbackText: String) {
        self.feedbackText = feedbackText
    }
}
