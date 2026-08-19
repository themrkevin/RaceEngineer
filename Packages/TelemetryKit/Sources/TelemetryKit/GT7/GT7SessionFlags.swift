import Foundation

public enum GT7SessionPhase: Sendable, Equatable {
    case loading
    case preSession
    case paused
    case driving
}

/// Candidate session-state bitmask decoded from GT7 Packet C offset 0x8E.
///
/// The previous implementation treated this word as `totalCars`, but live logs
/// showed values such as 0x0019 matching the apparent car count. Keep the raw
/// value available while the field mapping is validated against more states.
public struct GT7SessionFlags: Sendable, Equatable, OptionSet {
    public let rawValue: UInt16

    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }

    public static let carOnTrack = GT7SessionFlags(rawValue: 1 << 0)
    public static let gamePaused = GT7SessionFlags(rawValue: 1 << 1)
    public static let loading = GT7SessionFlags(rawValue: 1 << 2)
    public static let handbrakeActive = GT7SessionFlags(rawValue: 1 << 3)
    public static let revLimiterBlinking = GT7SessionFlags(rawValue: 1 << 4)
    public static let asmActive = GT7SessionFlags(rawValue: 1 << 5)
    public static let tcsActive = GT7SessionFlags(rawValue: 1 << 6)

    public var isCarOnTrack: Bool {
        contains(.carOnTrack)
    }

    public var isGamePaused: Bool {
        contains(.gamePaused)
    }

    public var isLoading: Bool {
        contains(.loading)
    }

    public var isHandbrakeActive: Bool {
        contains(.handbrakeActive)
    }

    public var isRevLimiterBlinking: Bool {
        contains(.revLimiterBlinking)
    }

    public var isASMActive: Bool {
        contains(.asmActive)
    }

    public var isTCSActive: Bool {
        contains(.tcsActive)
    }

    public var isActivelyDriving: Bool {
        isCarOnTrack && !isGamePaused && !isLoading
    }

    public var phase: GT7SessionPhase {
        if isLoading { return .loading }
        if !isCarOnTrack { return .preSession }
        if isGamePaused { return .paused }
        return .driving
    }
}
