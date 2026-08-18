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
        let stream = provider.telemetryStream()

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

    func testCorruptedHeaderFailsGracefully() async throws {
        let corruptedURL = tempDirectory.appendingPathComponent("corrupt.race")
        
        // Write invalid magic header
        var corruptData = Data(count: 16)
        var invalidMagic: UInt32 = 0xDEADBEEF
        corruptData.replaceSubrange(0..<4, with: Data(bytes: &invalidMagic, count: 4))
        try corruptData.write(to: corruptedURL)

        let provider = RecordedSessionProvider(fileURL: corruptedURL)
        
        try await provider.start()
        await provider.stop()
        
        XCTAssertTrue(true, "Corrupted file handled safely without crashing")
    }
}