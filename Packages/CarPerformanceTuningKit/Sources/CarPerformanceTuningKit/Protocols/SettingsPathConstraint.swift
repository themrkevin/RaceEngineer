public enum ChangeDirection: String, Sendable, Equatable, Codable {
    case increase
    case decrease
    case unspecified
}

/// Declares which change directions are plausible for a setting path; used to sanity-check proposals.
public struct SettingsPathConstraint: Sendable, Equatable, Codable {
    public let settingPath: String
    public let allowedDirections: Set<ChangeDirection>

    public init(settingPath: String, allowedDirections: Set<ChangeDirection>) {
        self.settingPath = settingPath
        self.allowedDirections = allowedDirections
    }
}
