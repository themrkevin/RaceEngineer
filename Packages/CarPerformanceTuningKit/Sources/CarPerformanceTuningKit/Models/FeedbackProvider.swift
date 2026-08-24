public protocol FeedbackProvider: Sendable {
    func feedback() -> DriverFeedbackBundle
}

/// POC provider returning fixed driver feedback text.
public struct StaticFeedbackProvider: FeedbackProvider {
    private let text: String

    public init(text: String) {
        self.text = text
    }

    public func feedback() -> DriverFeedbackBundle {
        DriverFeedbackBundle(feedbackText: text)
    }
}
