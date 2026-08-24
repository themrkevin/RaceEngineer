public enum SettingSource: String, Sendable, Equatable, Codable {
    case imageExtracted
    case manuallyEntered
    case userConfirmed
    case unknown
}

public struct SettingValue: Sendable, Equatable, Codable {
    public let rawValue: String?
    public let provenance: SettingSource

    public init(rawValue: String?, provenance: SettingSource) {
        self.rawValue = rawValue
        self.provenance = provenance
    }
}

/// Minimal setup snapshot keyed by dotted setting path (e.g. "transmission.finalGear").
public struct SettingsCatalogModel: Sendable, Equatable, Codable {
    public let values: [String: SettingValue]

    public init(values: [String: SettingValue]) {
        self.values = values
    }
}

/// Standard canonical dotted setting paths for vehicle setup sheets.
public enum SettingPathCatalog {
    // Suspension
    public static let suspensionType = "suspension.type"
    public static let suspensionBodyHeightFront = "suspension.bodyHeightMm.front"
    public static let suspensionBodyHeightRear = "suspension.bodyHeightMm.rear"
    public static let suspensionAntiRollBarFront = "suspension.antiRollBar.front"
    public static let suspensionAntiRollBarRear = "suspension.antiRollBar.rear"
    public static let suspensionDampingCompressionFront = "suspension.dampingCompressionPercent.front"
    public static let suspensionDampingCompressionRear = "suspension.dampingCompressionPercent.rear"
    public static let suspensionDampingExpansionFront = "suspension.dampingExpansionPercent.front"
    public static let suspensionDampingExpansionRear = "suspension.dampingExpansionPercent.rear"
    public static let suspensionNaturalFrequencyFront = "suspension.naturalFrequencyHz.front"
    public static let suspensionNaturalFrequencyRear = "suspension.naturalFrequencyHz.rear"
    public static let suspensionNegativeCamberFront = "suspension.camberDeg.front"
    public static let suspensionNegativeCamberRear = "suspension.camberDeg.rear"
    public static let suspensionToeAngleFront = "suspension.toeDeg.front"
    public static let suspensionToeAngleRear = "suspension.toeDeg.rear"

    // Differential
    public static let diffInitialTorqueFront = "differential.initialTorque.front"
    public static let diffInitialTorqueRear = "differential.initialTorque.rear"
    public static let diffAccelerationSensitivityFront = "differential.accelerationSensitivity.front"
    public static let diffAccelerationSensitivityRear = "differential.accelerationSensitivity.rear"
    public static let diffBrakingSensitivityFront = "differential.brakingSensitivity.front"
    public static let diffBrakingSensitivityRear = "differential.brakingSensitivity.rear"
    public static let diffCenterTorqueDistribution = "differential.centerTorqueDistribution"

    // Aerodynamics
    public static let downforceFront = "aerodynamics.downforce.front"
    public static let downforceRear = "aerodynamics.downforce.rear"

    // Power & ECU
    public static let ecuOutputAdjustment = "ecu.outputAdjustmentPercent"
    public static let ballastWeightKg = "performance.ballastKg"
    public static let ballastPosition = "performance.ballastPosition"
    public static let powerRestrictor = "performance.powerRestrictorPercent"

    // Transmission & Gearing
    public static let transmissionType = "transmission.type"
    public static let transmissionTopSpeedKmh = "transmission.topSpeedKmh"
    public static let transmissionFinalGear = "transmission.finalGear"

    // Brakes
    public static let brakeBalanceFrontRear = "brakes.balanceFrontRear"
}
