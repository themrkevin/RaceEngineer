import Foundation

/// Actor-isolated repository for discovering recorded `.race` sessions.
public actor RecordedSessionLibrary {
    public enum LibraryError: Error, Equatable, Sendable {
        case directoryUnavailable(URL)
    }

    private let directoryURL: URL

    public init(directoryURL: URL) {
        self.directoryURL = directoryURL
    }

    /// Returns valid `.race` files sorted newest first by filesystem creation date.
    public func sessions() throws -> [RecordedSessionSummary] {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw LibraryError.directoryUnavailable(directoryURL)
        }

        let urls = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey, .creationDateKey],
            options: [.skipsHiddenFiles]
        )

        return urls
            .filter { $0.pathExtension.caseInsensitiveCompare("race") == .orderedSame }
            .compactMap { url in
                guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey]),
                      values.isRegularFile == true else {
                    return nil
                }
                return RecordedSessionSummary(fileURL: url)
            }
            .sorted {
                if $0.creationDate != $1.creationDate {
                    return $0.creationDate > $1.creationDate
                }
                return $0.id < $1.id
            }
    }
}
