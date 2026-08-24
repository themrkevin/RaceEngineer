import XCTest
import TelemetryKit
@testable import CarPerformanceTuningKit

final class EndToEndEvidenceToRecommendationTests: XCTestCase {

    // MARK: - Real NSX sample (honest negative result)

    func testEndToEndPipelineOnNSXBaselineFindsNoFalseSluggishAccelerationFinding() async throws {
        let cornerEvidence = try loadNSXBaselineCornerEvidence()
        XCTAssertEqual(cornerEvidence.count, 22)

        let response = try await runPipeline(cornerEvidence: cornerEvidence, finalGearRawValue: nil)

        // Full-throttle NSX corner exits in this sample all show reasonable acceleration,
        // so the heuristic must not fabricate a sluggish-acceleration finding here.
        XCTAssertTrue(response.recommendations.isEmpty)
        XCTAssertTrue(EvidenceTraceValidator().validate(response, against: EvidenceBundle(cornerEvidence: cornerEvidence)))
    }

    // MARK: - Synthetic pattern (positive path)

    func testEndToEndPipelineFlagsSyntheticSluggishAccelerationPattern() async throws {
        let normalCorner = makeCornerEvidence(cornerIndex: 0, exitThrottle: 1.0, exitAcceleration: 4.0)
        let sluggishCorner = makeCornerEvidence(cornerIndex: 1, exitThrottle: 1.0, exitAcceleration: 0.5)
        let anotherNormalCorner = makeCornerEvidence(cornerIndex: 2, exitThrottle: 1.0, exitAcceleration: 3.5)

        let cornerEvidence = [normalCorner, sluggishCorner, anotherNormalCorner]
        let response = try await runPipeline(cornerEvidence: cornerEvidence, finalGearRawValue: "3.583")

        XCTAssertEqual(response.recommendations.count, 1)
        let recommendation = try XCTUnwrap(response.recommendations.first)
        XCTAssertEqual(recommendation.category, .accelerationDeployment)
        XCTAssertEqual(recommendation.evidenceReferences.map(\.cornerIndex), [1])

        let change = try XCTUnwrap(recommendation.proposedChanges.first)
        XCTAssertEqual(change.settingPath, "transmission.finalGear")
        XCTAssertEqual(change.currentValue, "3.583")
        XCTAssertEqual(change.direction, .increase)

        XCTAssertTrue(EvidenceTraceValidator().validate(response, against: EvidenceBundle(cornerEvidence: cornerEvidence)))
    }

    func testEvidenceTraceValidatorRejectsFabricatedReference() {
        let cornerEvidence = [makeCornerEvidence(cornerIndex: 0, exitThrottle: 1.0, exitAcceleration: 4.0)]
        let bundle = EvidenceBundle(cornerEvidence: cornerEvidence)

        let fabricated = TuningResponse(recommendations: [
            TuningRecommendation(
                category: .accelerationDeployment,
                confidence: 0.9,
                proposedChanges: [],
                rationale: "fabricated",
                evidenceReferences: [
                    EvidenceReference(cornerIndex: 0, metric: "exitAccelerationEstimateMetersPerSecondSquared", value: 999)
                ]
            )
        ])

        XCTAssertFalse(EvidenceTraceValidator().validate(fabricated, against: bundle))
    }

    // MARK: - Contract Codable Round-Trip Tests

    func testTuningRequestAndResponseJSONCodableRoundTrip() throws {
        let cornerEvidence = makeCornerEvidence(cornerIndex: 0, exitThrottle: 1.0, exitAcceleration: 4.0)
        let request = TuningRequest(
            setupSnapshot: SettingsCatalogModel(values: [
                SettingPathCatalog.transmissionFinalGear: SettingValue(rawValue: "3.583", provenance: .userConfirmed)
            ]),
            evidence: EvidenceBundle(cornerEvidence: [cornerEvidence]),
            feedback: DriverFeedbackBundle(feedbackText: "Test feedback")
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let requestData = try encoder.encode(request)
        let decodedRequest = try decoder.decode(TuningRequest.self, from: requestData)
        XCTAssertEqual(request, decodedRequest)

        let response = TuningResponse(recommendations: [
            TuningRecommendation(
                category: .accelerationDeployment,
                confidence: 0.85,
                proposedChanges: [
                    SetupChangeSuggestion(
                        settingPath: SettingPathCatalog.transmissionFinalGear,
                        currentValue: "3.583",
                        proposedValue: "shorter final gear ratio",
                        direction: .increase
                    )
                ],
                rationale: "Rationale test",
                evidenceReferences: [
                    EvidenceReference(cornerIndex: 0, metric: "exitAccelerationEstimateMetersPerSecondSquared", value: 4.0)
                ]
            )
        ])

        let responseData = try encoder.encode(response)
        let decodedResponse = try decoder.decode(TuningResponse.self, from: responseData)
        XCTAssertEqual(response, decodedResponse)
    }

    // MARK: - Pipeline helper

    private func runPipeline(cornerEvidence: [CornerEvidence], finalGearRawValue: String?) async throws -> TuningResponse {
        let evidenceBundle = PassthroughEvidenceExtractor().extractEvidence(from: cornerEvidence)
        let feedback = StaticFeedbackProvider(text: "i feel a little sluggish when accelerating, what can i change in my setup?").feedback()
        let setupSnapshot = SettingsCatalogModel(values: [
            "transmission.finalGear": SettingValue(
                rawValue: finalGearRawValue,
                provenance: finalGearRawValue == nil ? .unknown : .userConfirmed
            )
        ])

        let request = TuningRequestBuilder().makeRequest(
            setupSnapshot: setupSnapshot,
            evidence: evidenceBundle,
            feedback: feedback
        )

        let client: TuningAIClient = MockAIClient()
        return try await client.generateResponse(for: request)
    }

    private func makeCornerEvidence(cornerIndex: Int, exitThrottle: Float, exitAcceleration: Float) -> CornerEvidence {
        CornerEvidence(
            cornerIndex: cornerIndex,
            lapNumber: 1,
            anchorLapTimeSeconds: 10,
            anchorSessionTimeSeconds: 10,
            entryLapTimeSeconds: 8,
            entrySessionTimeSeconds: 8,
            minimumSpeedLapTimeSeconds: 11,
            minimumSpeedSessionTimeSeconds: 11,
            exitLapTimeSeconds: 14,
            exitSessionTimeSeconds: 14,
            throttlePickupLapTimeSeconds: 11.2,
            throttlePickupSessionTimeSeconds: 11.2,
            entrySpeedMetersPerSecond: 40,
            minimumSpeedMetersPerSecond: 20,
            exitSpeedMetersPerSecond: 30,
            speedRecoveryMetersPerSecond: 10,
            peakLateralCentripetalG: 1.2,
            entryGear: 2,
            minimumSpeedGear: 1,
            exitGear: 2,
            entryBrake: 0.8,
            exitThrottle: exitThrottle,
            throttlePickupDelaySeconds: 0.2,
            exitAccelerationEstimateMetersPerSecondSquared: exitAcceleration,
            isPossibleCorner: true,
            evidenceConfidence: 0.8,
            domainTags: CornerEvidenceDomainTags(
                rideControl: .unavailable,
                platformContact: .unavailable,
                gripUtilization: .ready,
                suspensionBehavior: .unavailable,
                aeroInfluence: .unavailable
            ),
            dataWarnings: []
        )
    }

    private func loadNSXBaselineCornerEvidence() throws -> [CornerEvidence] {
        let thisFileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = thisFileURL
            .deletingLastPathComponent() // CarPerformanceTuningKitTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // CarPerformanceTuningKit
            .deletingLastPathComponent() // Packages
            .deletingLastPathComponent() // RaceEngineer

        let reportURL = repoRoot
            .appendingPathComponent("docs")
            .appendingPathComponent("plan")
            .appendingPathComponent("reference")
            .appendingPathComponent("nsx-race-sample")
            .appendingPathComponent("nsx-events.json")

        let data = try Data(contentsOf: reportURL)
        let object = try JSONSerialization.jsonObject(with: data)
        let report = try XCTUnwrap(object as? [String: Any])
        let items = try XCTUnwrap(report["cornerEvidence"] as? [[String: Any]])

        return try items.map { item in
            let domainTagsJSON = try XCTUnwrap(item["domainTags"] as? [String: Any])

            return CornerEvidence(
                cornerIndex: try intValue(item["cornerIndex"]),
                lapNumber: try intValue(item["lapNumber"]),
                anchorLapTimeSeconds: doubleValue(item["anchorLapTimeSeconds"]),
                anchorSessionTimeSeconds: try doubleValue(required: item["anchorSessionTimeSeconds"]),
                entryLapTimeSeconds: doubleValue(item["entryLapTimeSeconds"]),
                entrySessionTimeSeconds: try doubleValue(required: item["entrySessionTimeSeconds"]),
                minimumSpeedLapTimeSeconds: doubleValue(item["minimumSpeedLapTimeSeconds"]),
                minimumSpeedSessionTimeSeconds: try doubleValue(required: item["minimumSpeedSessionTimeSeconds"]),
                exitLapTimeSeconds: doubleValue(item["exitLapTimeSeconds"]),
                exitSessionTimeSeconds: try doubleValue(required: item["exitSessionTimeSeconds"]),
                throttlePickupLapTimeSeconds: doubleValue(item["throttlePickupLapTimeSeconds"]),
                throttlePickupSessionTimeSeconds: doubleValue(item["throttlePickupSessionTimeSeconds"]),
                entrySpeedMetersPerSecond: try floatValue(item["entrySpeedMetersPerSecond"]),
                minimumSpeedMetersPerSecond: try floatValue(item["minimumSpeedMetersPerSecond"]),
                exitSpeedMetersPerSecond: try floatValue(item["exitSpeedMetersPerSecond"]),
                speedRecoveryMetersPerSecond: try floatValue(item["speedRecoveryMetersPerSecond"]),
                peakLateralCentripetalG: try floatValue(item["peakLateralCentripetalG"]),
                entryGear: try intValue(item["entryGear"]),
                minimumSpeedGear: try intValue(item["minimumSpeedGear"]),
                exitGear: try intValue(item["exitGear"]),
                entryBrake: try floatValue(item["entryBrake"]),
                exitThrottle: try floatValue(item["exitThrottle"]),
                throttlePickupDelaySeconds: doubleValue(item["throttlePickupDelaySeconds"]),
                exitAccelerationEstimateMetersPerSecondSquared: try floatValue(item["exitAccelerationEstimateMetersPerSecondSquared"]),
                isPossibleCorner: (item["isPossibleCorner"] as? Bool) ?? false,
                evidenceConfidence: try floatValue(item["evidenceConfidence"]),
                domainTags: CornerEvidenceDomainTags(
                    rideControl: try domainStatus(domainTagsJSON["rideControl"]),
                    platformContact: try domainStatus(domainTagsJSON["platformContact"]),
                    gripUtilization: try domainStatus(domainTagsJSON["gripUtilization"]),
                    suspensionBehavior: try domainStatus(domainTagsJSON["suspensionBehavior"]),
                    aeroInfluence: try domainStatus(domainTagsJSON["aeroInfluence"])
                ),
                dataWarnings: (item["dataWarnings"] as? [String]) ?? []
            )
        }
    }

    private func domainStatus(_ value: Any?) throws -> CornerEvidenceDomainStatus {
        let rawValue = try XCTUnwrap(value as? String)
        return try XCTUnwrap(CornerEvidenceDomainStatus(rawValue: rawValue))
    }

    private func intValue(_ value: Any?) throws -> Int {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        throw XCTSkip("Missing integer value")
    }

    private func floatValue(_ value: Any?) throws -> Float {
        if let value = value as? Float { return value }
        if let value = value as? Double { return Float(value) }
        if let value = value as? NSNumber { return value.floatValue }
        throw XCTSkip("Missing float value")
    }

    private func doubleValue(required value: Any?) throws -> Double {
        if let value = value as? Double { return value }
        if let value = value as? NSNumber { return value.doubleValue }
        throw XCTSkip("Missing double value")
    }

    private func doubleValue(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? NSNumber { return value.doubleValue }
        return nil
    }
}
