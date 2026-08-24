import XCTest
@testable import TelemetryKit

final class SessionRecordingTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TelemetryKitTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    // MARK: - Helpers

    /// Creates a mock 368-byte decrypted GT7 telemetry buffer with a specific engine RPM.
    private func makeMockFrame(rpm: Float) -> Data {
        var data = Data(count: 368)
        
        // 1. Magic Header 0x47375330 ("0S7G") at offset 0x00
        var magic: UInt32 = 0x47375330
        data.replaceSubrange(0..<4, with: Data(bytes: &magic, count: 4))

        // 2. Engine RPM (Float) at offset 0x3C (60)
        var engineRPM = rpm
        data.replaceSubrange(60..<64, with: Data(bytes: &engineRPM, count: 4))
        
        return data
    }

    // MARK: - Tests

    func testRecordingHeaderAndFrameSerialization() async throws {
        let fileURL = tempDirectory.appendingPathComponent("test_session.race")
        let recorder = TelemetryRecorder()

        // 1. Start recording
        try await recorder.startRecording(to: fileURL)

        // 2. Record 5 mock frames
        let frameCount = 5
        for i in 1...frameCount {
            let frame = makeMockFrame(rpm: Float(i * 1000))
            await recorder.recordFrame(frame)
        }

        // 3. Stop recording & flush to disk
        await recorder.stopRecording()

        // 4. Verify file existence & binary size: 16-byte header + (5 * 368 bytes) = 1856 bytes
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let fileSize = fileAttributes[.size] as? Int

        let expectedSize = 16 + (frameCount * 368)
        XCTAssertEqual(fileSize, expectedSize, "Recorded file size does not match expected header + frame total")

        // 5. Inspect 16-byte header raw magic bytes
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }

        guard let headerData = try handle.read(upToCount: 16), headerData.count == 16 else {
            XCTFail("Failed to read header data")
            return
        }

        let magic = headerData.prefix(4).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
        XCTAssertEqual(magic, 0x52414345, "Magic bytes should equal 'RACE' (0x52414345)")
    }

    func testPausedDiagnosticFrameIsStillRecorded() async throws {
        let fileURL = tempDirectory.appendingPathComponent("paused_frame.race")
        let recorder = TelemetryRecorder()

        try await recorder.startRecording(to: fileURL)
        await recorder.recordFrame(makeMockFrame(rpm: 4000.0), isGamePaused: true)
        await recorder.stopRecording()

        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let fileSize = try XCTUnwrap(attributes[.size] as? Int64)
        XCTAssertEqual(fileSize, Int64(RaceFileHeader.headerSize + 368))
    }

    func testEndToEndRecordingAndPlaybackStreaming() async throws {
        let fileURL = tempDirectory.appendingPathComponent("stream_test.race")
        let recorder = TelemetryRecorder()

        try await recorder.startRecording(to: fileURL)

        let expectedRPMs: [Float] = [3000.0, 4500.0, 6000.0, 7500.0]
        for rpm in expectedRPMs {
            let frame = makeMockFrame(rpm: rpm)
            await recorder.recordFrame(frame)
        }
        await recorder.stopRecording()

        // High playback speed (500x) for sub-second test execution
        let provider = RecordedSessionProvider(fileURL: fileURL, playbackSpeed: 500.0)
        let stream = await provider.telemetryStream()

        // Collector Task that encapsulates mutable state inside its own concurrency boundary
        let collectTask = Task<[Float], Never> {
            var rpms: [Float] = []
            for await packet in stream {
                rpms.append(packet.engineRPM)
                if rpms.count == expectedRPMs.count {
                    break
                }
            }
            return rpms
        }

        try await provider.start()

        let receivedRPMs = await collectTask.value
        await provider.stop()

        XCTAssertEqual(receivedRPMs, expectedRPMs, "Stream did not yield packets in the exact recorded sequence")
    }

    func testPlaybackProviderRejectsRestartAfterStreamFinishes() async throws {
        let fileURL = tempDirectory.appendingPathComponent("single_use.race")
        let recorder = TelemetryRecorder()
        try await recorder.startRecording(to: fileURL)
        await recorder.recordFrame(makeMockFrame(rpm: 3200.0))
        await recorder.stopRecording()

        let provider = RecordedSessionProvider(fileURL: fileURL, playbackSpeed: 500.0)
        let stream = await provider.telemetryStream()
        let readTask = Task {
            for await _ in stream {}
        }

        try await provider.start()
        await readTask.value

        do {
            try await provider.start()
            XCTFail("A finished playback stream should not be restarted")
        } catch let error as RecordedSessionError {
            XCTAssertEqual(error, .playbackStreamFinished)
        }
    }

    func testCorruptedHeaderFailsGracefully() async throws {
        let corruptedURL = tempDirectory.appendingPathComponent("corrupt.race")
        
        // Write invalid magic header
        var corruptData = Data(count: 16)
        var invalidMagic: UInt32 = 0xDEADBEEF
        corruptData.replaceSubrange(0..<4, with: Data(bytes: &invalidMagic, count: 4))
        try corruptData.write(to: corruptedURL)

        let provider = RecordedSessionProvider(fileURL: corruptedURL)
        let stream = await provider.telemetryStream()

        let readTask = Task<Int, Never> {
            var count = 0
            for await _ in stream {
                count += 1
            }
            return count
        }

        do {
            try await provider.start()
            XCTFail("Corrupted file should throw an invalid header error")
        } catch let error as RecordedSessionError {
            XCTAssertEqual(error, .invalidHeader)
        }
        let receivedCount = await readTask.value
        await provider.stop()
        
        XCTAssertEqual(receivedCount, 0, "Corrupted file should finish stream without yielding invalid packets")
    }

    func testUnsupportedHeaderFailsBeforePlayback() async throws {
        let fileURL = tempDirectory.appendingPathComponent("unsupported.race")
        let header = RaceFileHeader(packetSize: 396)
        try header.serialize().write(to: fileURL)

        let provider = RecordedSessionProvider(fileURL: fileURL)

        do {
            try await provider.start()
            XCTFail("Unsupported packet size should fail before playback")
        } catch let error as RecordedSessionError {
            XCTAssertEqual(error, .unsupportedHeader(header))
        }
    }

    func testTruncatedPayloadFailsBeforePlayback() async throws {
        let fileURL = tempDirectory.appendingPathComponent("truncated.race")
        let header = RaceFileHeader()
        var data = header.serialize()
        data.append(makeMockFrame(rpm: 3000.0).prefix(100))
        try data.write(to: fileURL)

        let provider = RecordedSessionProvider(fileURL: fileURL)

        do {
            try await provider.start()
            XCTFail("Truncated payload should fail before playback")
        } catch let error as RecordedSessionError {
            XCTAssertEqual(error, .truncatedFrame(expected: 368, actual: 100))
        }
    }

    func testRaceFileHeaderSerializationAndValidation() {
        let header = RaceFileHeader(
            version: 1,
            packetSize: 368,
            sampleRate: 60,
            flags: 0,
            reserved: 0
        )

        XCTAssertTrue(header.isValid)

        let serialized = header.serialize()
        XCTAssertEqual(serialized.count, 16)

        let deserialized = RaceFileHeader.deserialize(from: serialized)
        XCTAssertNotNil(deserialized)
        XCTAssertEqual(deserialized, header)
        XCTAssertEqual(deserialized?.packetSize, 368)
        XCTAssertEqual(deserialized?.sampleRate, 60)
    }

    /// Regression test: a transient delivery gap must never force-stop an in-progress recording.
    func testTelemetryGapDoesNotStopRecording() async throws {
        let fileURL = tempDirectory.appendingPathComponent("gap_test.race")
        let recorder = TelemetryRecorder()

        try await recorder.startRecording(to: fileURL)
        await recorder.recordFrame(makeMockFrame(rpm: 5000.0))

        // Exceed the watchdog's 3.5s staleness threshold with no frames arriving.
        try await Task.sleep(for: .seconds(4))

        let stateDuringGap = await recorder.currentRecordingState()
        XCTAssertTrue(stateDuringGap.isRecording, "A frame delivery gap must not stop recording")

        // Recording resumes normally after the gap and is still writing to the same file.
        await recorder.recordFrame(makeMockFrame(rpm: 5200.0))
        await recorder.stopRecording()

        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let fileSize = try XCTUnwrap(attributes[.size] as? Int64)
        XCTAssertEqual(fileSize, Int64(RaceFileHeader.headerSize + (2 * 368)), "Both frames straddling the gap should be persisted")
    }

    func testRecordedSessionSummaryMetadata() async throws {
        let fileURL = tempDirectory.appendingPathComponent("summary_test.race")
        let recorder = TelemetryRecorder()

        try await recorder.startRecording(to: fileURL)

        // 120 frames at 60Hz = 2.0 seconds
        let frameCount = 120
        for _ in 1...frameCount {
            let frame = makeMockFrame(rpm: 4000.0)
            await recorder.recordFrame(frame)
        }
        await recorder.stopRecording()

        let summary = RecordedSessionSummary(fileURL: fileURL)

        XCTAssertEqual(summary.id, fileURL.path, "Summary id must be deterministic based on fileURL")
        XCTAssertEqual(summary.fileName, "summary_test.race")
        XCTAssertEqual(summary.totalFrames, 120)
        XCTAssertEqual(summary.duration, 2.0, accuracy: 0.05)
        XCTAssertEqual(summary.formattedDuration, "00:02")
    }

    func testRecordedSessionLibraryFiltersAndSortsSessions() async throws {
        let olderURL = tempDirectory.appendingPathComponent("older.race")
        let newerURL = tempDirectory.appendingPathComponent("newer.RACE")
        let ignoredURL = tempDirectory.appendingPathComponent("notes.txt")

        try Data(repeating: 0, count: RaceFileHeader.headerSize).write(to: olderURL)
        try Data(repeating: 0, count: RaceFileHeader.headerSize).write(to: newerURL)
        try Data("ignore".utf8).write(to: ignoredURL)

        try FileManager.default.setAttributes(
            [.creationDate: Date(timeIntervalSince1970: 100)],
            ofItemAtPath: olderURL.path
        )
        try FileManager.default.setAttributes(
            [.creationDate: Date(timeIntervalSince1970: 200)],
            ofItemAtPath: newerURL.path
        )

        let library = RecordedSessionLibrary(directoryURL: tempDirectory)
        let sessions = try await library.sessions()

        XCTAssertEqual(sessions.map(\.fileName), ["newer.RACE", "older.race"])
    }

    func testTelemetryEventDetectorGroupsCandidateSamples() {
        let packets = [
            makeMockPacket(sequence: 0, speed: 30, yawRate: 0, brake: 0),
            makeMockPacket(sequence: 1, speed: 28, yawRate: 0.4, brake: 1),
            makeMockPacket(sequence: 2, speed: 25, yawRate: 0.8, brake: 1),
            makeMockPacket(sequence: 3, speed: 24, yawRate: 2.0, brake: 0),
            makeMockPacket(sequence: 4, speed: 24, yawRate: 2.0, brake: 0),
            makeMockPacket(sequence: 5, speed: 24, yawRate: 0, brake: 0)
        ]

        let events = TelemetryEventDetector().detect(packets: packets, sampleRate: 60)

        XCTAssertEqual(events.count, 1)
        XCTAssertTrue(events[0].kinds.contains(.hardBraking))
        XCTAssertTrue(events[0].kinds.contains(.rapidRotation))
        XCTAssertEqual(events[0].lapNumber, 0)
    }

    func testTelemetryEventDetectorDetectsFullStopAfterDisturbance() {
        let packets = [
            makeMockPacket(sequence: 0, speed: 20, yawRate: 0, brake: 0),
            makeMockPacket(sequence: 1, speed: 0.5, yawRate: 1.8, brake: 0),
            makeMockPacket(sequence: 2, speed: 0.2, yawRate: 1.7, brake: 0)
        ]

        let events = TelemetryEventDetector().detect(packets: packets, sampleRate: 60)

        XCTAssertEqual(events.count, 1)
        XCTAssertTrue(events[0].kinds.contains(.fullStop))
        XCTAssertTrue(events[0].kinds.contains(.rapidRotation))
        XCTAssertTrue(events[0].kinds.contains(.vehicleDisturbance))
    }

    func testTelemetryEventDetectorPreservesSeparateDisturbanceEvents() {
        let packets = [
            makeMockPacket(sequence: 0, speed: 25, yawRate: 0, brake: 0),
            makeMockPacket(sequence: 1, speed: 24, yawRate: 1.6, brake: 0),
            makeMockPacket(sequence: 2, speed: 20, yawRate: 1.8, brake: 0),
            makeMockPacket(sequence: 3, speed: 18, yawRate: 1.7, brake: 0),
            makeMockPacket(sequence: 4, speed: 17, yawRate: 1.6, brake: 0),
            makeMockPacket(sequence: 5, speed: 16, yawRate: 0, brake: 0)
        ]

        let configuration = TelemetryEventDetectorConfiguration(groupingInterval: 0.5)
        let events = TelemetryEventDetector(configuration: configuration)
            .detect(packets: packets, sampleRate: 1)

        XCTAssertEqual(events.count, 5)
        XCTAssertTrue(events.allSatisfy { $0.kinds.contains(.rapidRotation) })
    }

    func testTelemetryEventDetectorLeavesInitialPartialLapUntimed() {
        let packets = [
            makeMockPacket(sequence: 100, speed: 25, yawRate: 0, brake: 0, lap: 2),
            makeMockPacket(sequence: 101, speed: 24, yawRate: 1.6, brake: 0, lap: 2)
        ]

        let events = TelemetryEventDetector().detect(packets: packets, sampleRate: 60)

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].lapNumber, 2)
        XCTAssertNil(events[0].lapTime)
        XCTAssertEqual(events[0].sessionTime, 1.0 / 60.0, accuracy: 0.0001)
    }

    func testTelemetryEventDetectorTimesEventsFromObservedLapTransition() {
        let packets = [
            makeMockPacket(sequence: 100, speed: 25, yawRate: 0, brake: 0, lap: 2),
            makeMockPacket(sequence: 101, speed: 24, yawRate: 0, brake: 0, lap: 3),
            makeMockPacket(sequence: 102, speed: 23, yawRate: 1.6, brake: 0, lap: 3)
        ]

        let events = TelemetryEventDetector().detect(packets: packets, sampleRate: 60)

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].lapNumber, 3)
        XCTAssertEqual(events[0].lapTime ?? -1, 1.0 / 60.0, accuracy: 0.0001)
    }

    func testCornerPerformanceAnalyzerBuildsWindowAroundBrakingAnchor() {
        let packets = [
            makeMockPacket(sequence: 0, speed: 30, yawRate: 0, brake: 0, throttle: 0, steeringAngle: 0.2, gear: 2),
            makeMockPacket(sequence: 1, speed: 29, yawRate: 0.2, brake: 1, throttle: 0, steeringAngle: 0.3, gear: 1),
            makeMockPacket(sequence: 2, speed: 10, yawRate: 0.4, brake: 1, throttle: 0, steeringAngle: 0.4, gear: 1),
            makeMockPacket(sequence: 3, speed: 12, yawRate: 0.3, brake: 0, throttle: 0.5, steeringAngle: 0.2, gear: 1),
            makeMockPacket(sequence: 4, speed: 16, yawRate: 0.1, brake: 0, throttle: 0.8, steeringAngle: 0.1, gear: 2)
        ]

        let events = TelemetryEventDetector().detect(packets: packets, sampleRate: 10)
        let windows = CornerPerformanceAnalyzer().analyze(
            packets: packets,
            events: events,
            sampleRate: 10
        )

        XCTAssertEqual(windows.count, 1)
        XCTAssertTrue(windows[0].isPossibleCorner)
        XCTAssertEqual(windows[0].entryGear, packets[0].gear)
        XCTAssertEqual(windows[0].minimumSpeedMetersPerSecond, 10, accuracy: 0.001)
        XCTAssertEqual(windows[0].minimumSpeedGear, packets[2].gear)
        XCTAssertEqual(windows[0].exitGear, packets[3].gear)
        XCTAssertEqual(windows[0].exitThrottle, 0.5, accuracy: 0.01)
        XCTAssertEqual(windows[0].speedRecoveryMetersPerSecond, 2, accuracy: 0.001)
    }

    func testCornerEvidenceExtractorProducesDeterministicEvidenceFromWindow() {
        let packets = [
            makeMockPacket(sequence: 0, speed: 30, yawRate: 0, brake: 0, throttle: 0, steeringAngle: 0.2, gear: 2),
            makeMockPacket(sequence: 1, speed: 29, yawRate: 0.2, brake: 1, throttle: 0, steeringAngle: 0.3, gear: 1),
            makeMockPacket(sequence: 2, speed: 10, yawRate: 0.4, brake: 1, throttle: 0, steeringAngle: 0.4, gear: 1),
            makeMockPacket(sequence: 3, speed: 12, yawRate: 0.3, brake: 0, throttle: 0.5, steeringAngle: 0.2, gear: 1),
            makeMockPacket(sequence: 4, speed: 16, yawRate: 0.1, brake: 0, throttle: 0.8, steeringAngle: 0.1, gear: 2)
        ]

        let events = TelemetryEventDetector().detect(packets: packets, sampleRate: 10)
        let windows = CornerPerformanceAnalyzer().analyze(
            packets: packets,
            events: events,
            sampleRate: 10
        )
        let evidence = CornerEvidenceExtractor().extract(
            packets: packets,
            windows: windows,
            sampleRate: 10
        )

        XCTAssertEqual(windows.count, 1)
        XCTAssertEqual(evidence.count, 1)

        let item = evidence[0]
        XCTAssertEqual(item.cornerIndex, 0)
        XCTAssertEqual(item.lapNumber, 0)
        XCTAssertEqual(item.entryGear, 2)
        XCTAssertEqual(item.minimumSpeedGear, 1)
        XCTAssertEqual(item.exitGear, 1)
        XCTAssertEqual(item.entryLapTimeSeconds, nil)
        XCTAssertEqual(item.minimumSpeedLapTimeSeconds, nil)
        XCTAssertEqual(item.exitLapTimeSeconds, nil)
        XCTAssertEqual(item.throttlePickupDelaySeconds ?? -1, 0.1, accuracy: 0.0001)
        XCTAssertEqual(item.exitAccelerationEstimateMetersPerSecondSquared, 20, accuracy: 0.001)
        XCTAssertEqual(item.domainTags.gripUtilization, .ready)
        XCTAssertEqual(item.domainTags.rideControl, .caution)
        XCTAssertEqual(item.domainTags.platformContact, .caution)
        XCTAssertEqual(item.domainTags.suspensionBehavior, .caution)
        XCTAssertEqual(item.domainTags.aeroInfluence, .unavailable)
        XCTAssertTrue(item.dataWarnings.contains("domainSignalsUnavailable:aeroHighSpeedContext"))
        XCTAssertTrue(item.evidenceConfidence >= 0 && item.evidenceConfidence <= 1)
    }

    func testCornerEvidenceExtractorNSXBaselineFieldPresenceAndDeterministicCount() throws {
        let report = try loadNSXBaselineReport()
        let baselineWindows = try baselineCornerWindows(from: report)
        let evidence = CornerEvidenceExtractor().extract(
            packets: [],
            windows: baselineWindows,
            sampleRate: 60
        )

        XCTAssertEqual(baselineWindows.count, 22)
        XCTAssertEqual(evidence.count, 22)
        XCTAssertEqual(evidence.count, baselineWindows.count)

        for (index, item) in evidence.enumerated() {
            XCTAssertEqual(item.cornerIndex, index)
            XCTAssertTrue(item.entrySpeedMetersPerSecond.isFinite)
            XCTAssertTrue(item.minimumSpeedMetersPerSecond.isFinite)
            XCTAssertTrue(item.exitSpeedMetersPerSecond.isFinite)
            XCTAssertTrue(item.speedRecoveryMetersPerSecond.isFinite)
            XCTAssertTrue(item.peakLateralCentripetalG.isFinite)
            XCTAssertTrue(item.evidenceConfidence >= 0)
            XCTAssertTrue(item.evidenceConfidence <= 1)
            XCTAssertEqual(item.anchorSessionTimeSeconds.isFinite, true)
            XCTAssertEqual(item.entrySessionTimeSeconds.isFinite, true)
            XCTAssertEqual(item.minimumSpeedSessionTimeSeconds.isFinite, true)
            XCTAssertEqual(item.exitSessionTimeSeconds.isFinite, true)
            XCTAssertEqual(item.domainTags.gripUtilization, .ready)
            XCTAssertEqual(item.domainTags.rideControl, .unavailable)
            XCTAssertEqual(item.domainTags.platformContact, .unavailable)
            XCTAssertEqual(item.domainTags.suspensionBehavior, .unavailable)
            XCTAssertEqual(item.domainTags.aeroInfluence, .unavailable)
            XCTAssertTrue(item.dataWarnings.contains("domainSignalsUnavailable:rideAndSuspension"))
            XCTAssertTrue(item.dataWarnings.contains("domainSignalsUnavailable:aeroPacketSlice"))
        }
    }

    func testNSXBaselineReportFreezesTicketZeroInvariants() throws {
        let report = try loadNSXBaselineReport()

        XCTAssertEqual(report["schemaVersion"] as? String, "1.2")

        let events = try XCTUnwrap(report["events"] as? [[String: Any]])
        XCTAssertEqual(events.count, 27)

        let windows = try XCTUnwrap(report["cornerPerformanceWindows"] as? [[String: Any]])
        XCTAssertEqual(windows.count, 22)
        XCTAssertTrue(windows.allSatisfy { ($0["isPossibleCorner"] as? Bool) == true })
    }

    func testNSXBaselineCornerTimingUsesLapFirstWithSessionCompanion() throws {
        let report = try loadNSXBaselineReport()
        let windows = try XCTUnwrap(report["cornerPerformanceWindows"] as? [[String: Any]])
        XCTAssertFalse(windows.isEmpty)

        var observedThrottlePickup = false

        for (index, window) in windows.enumerated() {
            let debug = "window index \(index)"

            XCTAssertNotNil(window["anchorSessionTimeSeconds"], "Missing anchorSessionTimeSeconds for \(debug)")
            XCTAssertNotNil(window["entrySessionTimeSeconds"], "Missing entrySessionTimeSeconds for \(debug)")
            XCTAssertNotNil(window["minimumSpeedSessionTimeSeconds"], "Missing minimumSpeedSessionTimeSeconds for \(debug)")
            XCTAssertNotNil(window["exitSessionTimeSeconds"], "Missing exitSessionTimeSeconds for \(debug)")

            let anchorLapTime = doubleValue(window["anchorLapTimeSeconds"])
            let anchorSessionTime = try XCTUnwrap(doubleValue(window["anchorSessionTimeSeconds"]), "Missing anchorSessionTimeSeconds for \(debug)")

            let entrySessionTime = try XCTUnwrap(doubleValue(window["entrySessionTimeSeconds"]), "Missing entrySessionTimeSeconds for \(debug)")
            let minimumSessionTime = try XCTUnwrap(doubleValue(window["minimumSpeedSessionTimeSeconds"]), "Missing minimumSpeedSessionTimeSeconds for \(debug)")
            let exitSessionTime = try XCTUnwrap(doubleValue(window["exitSessionTimeSeconds"]), "Missing exitSessionTimeSeconds for \(debug)")

            if let anchorLapTime {
                let entryLapTime = try XCTUnwrap(doubleValue(window["entryLapTimeSeconds"]), "Missing entryLapTimeSeconds for \(debug)")
                let minimumLapTime = try XCTUnwrap(doubleValue(window["minimumSpeedLapTimeSeconds"]), "Missing minimumSpeedLapTimeSeconds for \(debug)")
                let exitLapTime = try XCTUnwrap(doubleValue(window["exitLapTimeSeconds"]), "Missing exitLapTimeSeconds for \(debug)")

                XCTAssertEqual(
                    entryLapTime - anchorLapTime,
                    entrySessionTime - anchorSessionTime,
                    accuracy: 0.0001,
                    "Entry lap/session delta mismatch for \(debug)"
                )
                XCTAssertEqual(
                    minimumLapTime - anchorLapTime,
                    minimumSessionTime - anchorSessionTime,
                    accuracy: 0.0001,
                    "Minimum-speed lap/session delta mismatch for \(debug)"
                )
                XCTAssertEqual(
                    exitLapTime - anchorLapTime,
                    exitSessionTime - anchorSessionTime,
                    accuracy: 0.0001,
                    "Exit lap/session delta mismatch for \(debug)"
                )
            }

            if let throttleLapTime = doubleValue(window["throttlePickupLapTimeSeconds"]) {
                observedThrottlePickup = true
                let throttleSessionTime = try XCTUnwrap(doubleValue(window["throttlePickupSessionTimeSeconds"]), "Missing throttlePickupSessionTimeSeconds for \(debug)")
                if let anchorLapTime {
                    XCTAssertEqual(
                        throttleLapTime - anchorLapTime,
                        throttleSessionTime - anchorSessionTime,
                        accuracy: 0.0001,
                        "Throttle-pickup lap/session delta mismatch for \(debug)"
                    )
                }
            }
        }

        XCTAssertTrue(observedThrottlePickup, "Expected at least one baseline window with throttle-pickup timing")
    }

    private func loadNSXBaselineReport() throws -> [String: Any] {
        let thisFileURL = URL(fileURLWithPath: #filePath)
        let packageRoot = thisFileURL
            .deletingLastPathComponent() // TelemetryKitTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // TelemetryKit
        let repoRoot = packageRoot
            .deletingLastPathComponent() // Packages
            .deletingLastPathComponent() // RaceEngineer

        let reportURL = repoRoot
            .appendingPathComponent("docs")
            .appendingPathComponent("plan")
            .appendingPathComponent("reference")
            .appendingPathComponent("nsx-race-sample")
            .appendingPathComponent("nsx-events.json")

        XCTAssertTrue(FileManager.default.fileExists(atPath: reportURL.path), "Missing baseline report at \(reportURL.path)")
        let data = try Data(contentsOf: reportURL)
        let object = try JSONSerialization.jsonObject(with: data)
        return try XCTUnwrap(object as? [String: Any])
    }

    private func baselineCornerWindows(from report: [String: Any]) throws -> [CornerPerformanceWindow] {
        let cornerObjects = try XCTUnwrap(report["cornerPerformanceWindows"] as? [[String: Any]])

        return try cornerObjects.enumerated().map { index, object in
            let lapNumber = try intValue(object["lapNumber"], key: "lapNumber", index: index)
            let anchorLapTime = doubleValue(object["anchorLapTimeSeconds"])
            let anchorSessionTime = try doubleValue(object["anchorSessionTimeSeconds"], key: "anchorSessionTimeSeconds", index: index)
            let entryTime = try doubleValue(object["entrySessionTimeSeconds"], key: "entrySessionTimeSeconds", index: index)
            let minimumTime = try doubleValue(object["minimumSpeedSessionTimeSeconds"], key: "minimumSpeedSessionTimeSeconds", index: index)
            let exitTime = try doubleValue(object["exitSessionTimeSeconds"], key: "exitSessionTimeSeconds", index: index)
            let throttlePickupTime = doubleValue(object["throttlePickupSessionTimeSeconds"])

            let event = TelemetryEvent(
                kinds: [.hardBraking],
                startTime: anchorSessionTime,
                peakTime: anchorSessionTime,
                endTime: anchorSessionTime,
                sessionTime: anchorSessionTime,
                lapTime: anchorLapTime,
                lapNumber: lapNumber,
                peakSpeedMetersPerSecond: floatValue(object["entrySpeedMetersPerSecond"]) ?? 0,
                peakYawRateRadiansPerSecond: 0,
                peakLateralCentripetalG: floatValue(object["peakLateralCentripetalG"]) ?? 0,
                peakWheelSpeedSpreadRatio: 0,
                gearBefore: intValue(object["entryGear"]) ?? 0,
                gearAtPeak: intValue(object["minimumSpeedGear"]) ?? 0,
                throttleAtPeak: floatValue(object["exitThrottle"]) ?? 0,
                brakeAtPeak: floatValue(object["entryBrake"]) ?? 0,
                speedBeforeMetersPerSecond: floatValue(object["entrySpeedMetersPerSecond"]) ?? 0,
                speedAfterMetersPerSecond: floatValue(object["exitSpeedMetersPerSecond"]) ?? 0,
                confidence: 1
            )

            return CornerPerformanceWindow(
                anchorEvent: event,
                entryTime: entryTime,
                entrySpeedMetersPerSecond: try floatValue(object["entrySpeedMetersPerSecond"], key: "entrySpeedMetersPerSecond", index: index),
                entryGear: try intValue(object["entryGear"], key: "entryGear", index: index),
                entryBrake: try floatValue(object["entryBrake"], key: "entryBrake", index: index),
                minimumSpeedTime: minimumTime,
                minimumSpeedMetersPerSecond: try floatValue(object["minimumSpeedMetersPerSecond"], key: "minimumSpeedMetersPerSecond", index: index),
                minimumSpeedGear: try intValue(object["minimumSpeedGear"], key: "minimumSpeedGear", index: index),
                peakLateralCentripetalG: try floatValue(object["peakLateralCentripetalG"], key: "peakLateralCentripetalG", index: index),
                throttlePickupTime: throttlePickupTime,
                exitTime: exitTime,
                exitSpeedMetersPerSecond: try floatValue(object["exitSpeedMetersPerSecond"], key: "exitSpeedMetersPerSecond", index: index),
                exitGear: try intValue(object["exitGear"], key: "exitGear", index: index),
                exitThrottle: try floatValue(object["exitThrottle"], key: "exitThrottle", index: index),
                speedRecoveryMetersPerSecond: try floatValue(object["speedRecoveryMetersPerSecond"], key: "speedRecoveryMetersPerSecond", index: index),
                isPossibleCorner: (object["isPossibleCorner"] as? Bool) ?? false
            )
        }
    }

    private func doubleValue(_ value: Any?, key: String, index: Int) throws -> Double {
        if let value = value as? Double { return value }
        if let value = value as? NSNumber { return value.doubleValue }
        throw NSError(
            domain: "TelemetryKitTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Missing or invalid \(key) at corner index \(index)"]
        )
    }

    private func floatValue(_ value: Any?, key: String, index: Int) throws -> Float {
        if let value = value as? Float { return value }
        if let value = value as? Double { return Float(value) }
        if let value = value as? NSNumber { return value.floatValue }
        throw NSError(
            domain: "TelemetryKitTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Missing or invalid \(key) at corner index \(index)"]
        )
    }

    private func floatValue(_ value: Any?) -> Float? {
        if let value = value as? Float { return value }
        if let value = value as? Double { return Float(value) }
        if let value = value as? NSNumber { return value.floatValue }
        return nil
    }

    private func intValue(_ value: Any?, key: String, index: Int) throws -> Int {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        throw NSError(
            domain: "TelemetryKitTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Missing or invalid \(key) at corner index \(index)"]
        )
    }

    private func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        return nil
    }

    private func doubleValue(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? NSNumber { return value.doubleValue }
        return nil
    }

    private func makeMockPacket(
        sequence: Int32,
        speed: Float,
        yawRate: Float,
        brake: Float,
        lap: Int16 = 0,
        throttle: Float = 0,
        steeringAngle: Float = 0,
        gear: Int = 0
    ) -> GT7Packet {
        var data = Data(count: 368)
        var magic: UInt32 = 0x47375330
        var packetSequence = sequence
        var velocity = SIMD3<Float>(speed, 0, 0)
        var angularVelocity = SIMD3<Float>(0, yawRate, 0)
        var carSpeed = speed
        var currentLap = lap
        var steering = steeringAngle

        data.replaceSubrange(0..<4, with: Data(bytes: &magic, count: 4))
        data.replaceSubrange(0x10..<0x14, with: Data(bytes: &velocity.x, count: 4))
        data.replaceSubrange(0x14..<0x18, with: Data(bytes: &velocity.y, count: 4))
        data.replaceSubrange(0x18..<0x1C, with: Data(bytes: &velocity.z, count: 4))
        data.replaceSubrange(0x2C..<0x30, with: Data(bytes: &angularVelocity.x, count: 4))
        data.replaceSubrange(0x30..<0x34, with: Data(bytes: &angularVelocity.y, count: 4))
        data.replaceSubrange(0x34..<0x38, with: Data(bytes: &angularVelocity.z, count: 4))
        data.replaceSubrange(0x4C..<0x50, with: Data(bytes: &carSpeed, count: 4))
        data.replaceSubrange(0x70..<0x74, with: Data(bytes: &packetSequence, count: 4))
        data.replaceSubrange(0x74..<0x76, with: Data(bytes: &currentLap, count: 2))
        data[0x90] = UInt8(gear & 0x0F)
        data[0x91] = UInt8((throttle * 255).rounded())
        data[0x92] = UInt8((brake * 255).rounded())
        data.replaceSubrange(0x12C..<0x130, with: Data(bytes: &steering, count: 4))
        return GT7Packet(decryptedData: data)
    }

    func testRecordedSessionLibraryRejectsMissingDirectory() async throws {
        let missingURL = tempDirectory.appendingPathComponent("missing")
        let library = RecordedSessionLibrary(directoryURL: missingURL)

        do {
            _ = try await library.sessions()
            XCTFail("A missing recordings directory should throw")
        } catch let error as RecordedSessionLibrary.LibraryError {
            XCTAssertEqual(error, .directoryUnavailable(missingURL))
        }
    }

    func testHighVolumeIngressPersistsEveryFrame() async throws {
        let fileURL = tempDirectory.appendingPathComponent("high_volume.race")
        let recorder = TelemetryRecorder()
        let frameCount = 2_000

        try await recorder.startRecording(to: fileURL)

        for index in 0..<frameCount {
            recorder.processFrameDirect(
                rawData: makeMockFrame(rpm: Float(index)),
                isGamePaused: false
            )
        }

        await recorder.flushIngress()
        await recorder.stopRecording()

        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let fileSize = try XCTUnwrap(attributes[.size] as? Int64)
        let expectedSize = Int64(RaceFileHeader.headerSize + frameCount * 368)

        XCTAssertEqual(fileSize, expectedSize, "Every accepted ingress frame must be persisted")
    }
}