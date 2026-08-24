import Foundation
import TelemetryKit

struct EventReport: Codable {
    let schemaVersion: String
    let generatedAt: Date
    let sourceFile: String
    let session: SessionReport
    let detector: DetectorReport
    let query: QueryReport?
    let events: [EventReportItem]
    let cornerPerformanceWindows: [CornerPerformanceReport]
}

struct SessionReport: Codable {
    let packetCount: Int
    let sampleRateHz: UInt16
    let durationSeconds: TimeInterval
    let vehicleCode: Int32?
    let lapRange: LapRangeReport?
    let phases: [String]
    let invalidPacketCount: Int
    let sequenceGapCount: Int
    let speedMetersPerSecond: RangeReport
    let steeringAngle: RangeReport
    let throttle: RangeReport
    let brake: RangeReport
    let engineRPM: RangeReport
    let tireSurfaceTemperature: RangeReport
    let suspensionTravel: RangeReport
    let accelerationMagnitudeG: RangeReport
    let lateralCentripetalG: RangeReport
    let derivedAccelerationSampleCount: Int
    let peakAccelerationEvent: DerivedEventReport?
    let peakLateralCentripetalEvent: DerivedEventReport?
}

struct RangeReport: Codable {
    let minimum: Float?
    let maximum: Float?

    init(_ range: TelemetryRange) {
        minimum = range.minimum
        maximum = range.maximum
    }
}

struct DerivedEventReport: Codable {
    let packetIndex: Int
    let elapsedTimeSeconds: TimeInterval
    let lapElapsedTimeSeconds: TimeInterval?
    let lapNumber: Int
    let phase: String
    let valueG: Float
    let speedMetersPerSecond: Float
    let yawRateRadiansPerSecond: Float

    init(_ event: DerivedTelemetryEvent) {
        packetIndex = event.packetIndex
        elapsedTimeSeconds = event.elapsedTime
        lapElapsedTimeSeconds = event.lapElapsedTime
        lapNumber = event.lapNumber
        phase = String(describing: event.phase)
        valueG = event.valueG
        speedMetersPerSecond = event.speedMetersPerSecond
        yawRateRadiansPerSecond = event.yawRateRadiansPerSecond
    }
}

struct LapRangeReport: Codable {
    let minimum: Int
    let maximum: Int
}

struct DetectorReport: Codable {
    let eventKinds: [String]
    let groupingIntervalSeconds: TimeInterval
}

struct QueryReport: Codable {
    let lap: Int?
    let rangeStartSeconds: TimeInterval?
    let rangeEndSeconds: TimeInterval?
    let kind: String?
    let nearLap: Int?
    let nearTimeSeconds: TimeInterval?
    let nearToleranceSeconds: TimeInterval?
}

struct EventReportItem: Codable {
    let kinds: [String]
    let startTimeSeconds: TimeInterval
    let peakTimeSeconds: TimeInterval
    let endTimeSeconds: TimeInterval
    let lapTimeSeconds: TimeInterval?
    let lapNumber: Int
    let peakSpeedMetersPerSecond: Float
    let peakYawRateRadiansPerSecond: Float
    let peakLateralCentripetalG: Float
    let peakWheelSpeedSpreadRatio: Float
    let gearBefore: Int
    let gearAtPeak: Int
    let throttleAtPeak: Float
    let brakeAtPeak: Float
    let speedBeforeMetersPerSecond: Float
    let speedAfterMetersPerSecond: Float
    let confidence: Float

    init(_ event: TelemetryEvent) {
        kinds = event.kinds.map(\.rawValue).sorted()
        startTimeSeconds = event.startTime
        peakTimeSeconds = event.sessionTime
        endTimeSeconds = event.endTime
        lapTimeSeconds = event.lapTime
        lapNumber = event.lapNumber
        peakSpeedMetersPerSecond = event.peakSpeedMetersPerSecond
        peakYawRateRadiansPerSecond = event.peakYawRateRadiansPerSecond
        peakLateralCentripetalG = event.peakLateralCentripetalG
        peakWheelSpeedSpreadRatio = event.peakWheelSpeedSpreadRatio
        gearBefore = event.gearBefore
        gearAtPeak = event.gearAtPeak
        throttleAtPeak = event.throttleAtPeak
        brakeAtPeak = event.brakeAtPeak
        speedBeforeMetersPerSecond = event.speedBeforeMetersPerSecond
        speedAfterMetersPerSecond = event.speedAfterMetersPerSecond
        confidence = event.confidence
    }
}

struct CornerPerformanceReport: Codable {
    let lapNumber: Int
    let anchorLapTimeSeconds: TimeInterval?
    let anchorSessionTimeSeconds: TimeInterval
    let entryLapTimeSeconds: TimeInterval?
    let entrySessionTimeSeconds: TimeInterval
    let entrySpeedMetersPerSecond: Float
    let entryGear: Int
    let entryBrake: Float
    let minimumSpeedLapTimeSeconds: TimeInterval?
    let minimumSpeedSessionTimeSeconds: TimeInterval
    let minimumSpeedMetersPerSecond: Float
    let minimumSpeedGear: Int
    let peakLateralCentripetalG: Float
    let throttlePickupLapTimeSeconds: TimeInterval?
    let throttlePickupSessionTimeSeconds: TimeInterval?
    let exitLapTimeSeconds: TimeInterval?
    let exitSessionTimeSeconds: TimeInterval
    let exitSpeedMetersPerSecond: Float
    let exitGear: Int
    let exitThrottle: Float
    let speedRecoveryMetersPerSecond: Float
    let isPossibleCorner: Bool

    init(_ window: CornerPerformanceWindow) {
        let anchorLapTime = window.anchorEvent.lapTime
        let anchorSessionTime = window.anchorEvent.sessionTime

        lapNumber = window.anchorEvent.lapNumber
        anchorLapTimeSeconds = anchorLapTime
        anchorSessionTimeSeconds = anchorSessionTime
        entrySessionTimeSeconds = window.entryTime
        entryLapTimeSeconds = lapTime(anchorLapTime: anchorLapTime, anchorSessionTime: anchorSessionTime, targetSessionTime: window.entryTime)
        entrySpeedMetersPerSecond = window.entrySpeedMetersPerSecond
        entryGear = window.entryGear
        entryBrake = window.entryBrake
        minimumSpeedSessionTimeSeconds = window.minimumSpeedTime
        minimumSpeedLapTimeSeconds = lapTime(anchorLapTime: anchorLapTime, anchorSessionTime: anchorSessionTime, targetSessionTime: window.minimumSpeedTime)
        minimumSpeedMetersPerSecond = window.minimumSpeedMetersPerSecond
        minimumSpeedGear = window.minimumSpeedGear
        peakLateralCentripetalG = window.peakLateralCentripetalG
        throttlePickupSessionTimeSeconds = window.throttlePickupTime
        throttlePickupLapTimeSeconds = window.throttlePickupTime.flatMap {
            lapTime(anchorLapTime: anchorLapTime, anchorSessionTime: anchorSessionTime, targetSessionTime: $0)
        }
        exitSessionTimeSeconds = window.exitTime
        exitLapTimeSeconds = lapTime(anchorLapTime: anchorLapTime, anchorSessionTime: anchorSessionTime, targetSessionTime: window.exitTime)
        exitSpeedMetersPerSecond = window.exitSpeedMetersPerSecond
        exitGear = window.exitGear
        exitThrottle = window.exitThrottle
        speedRecoveryMetersPerSecond = window.speedRecoveryMetersPerSecond
        isPossibleCorner = window.isPossibleCorner
    }
}

struct QueryOptions {
    let lap: Int?
    let range: ClosedRange<TimeInterval>?
    let kind: String?
    let nearLap: Int?
    let nearTime: TimeInterval?
    let nearTolerance: TimeInterval
    let outputURL: URL
    let textOutputURL: URL?
}

guard CommandLine.arguments.count >= 2 else {
    printUsageAndExit()
}

let fileURL = URL(fileURLWithPath: CommandLine.arguments[1])

do {
    let options = try parseOptions(Array(CommandLine.arguments.dropFirst(2)), sourceURL: fileURL)
    let inspection = try RecordedSessionInspector().inspect(fileURL: fileURL)
    let packets = try loadPackets(from: fileURL, header: inspection.header)
    let configuration = TelemetryEventDetectorConfiguration()
    let events = TelemetryEventDetector(configuration: configuration)
        .detect(packets: packets, sampleRate: inspection.header.sampleRate)
    let cornerWindows = CornerPerformanceAnalyzer().analyze(
        packets: packets,
        events: events,
        sampleRate: inspection.header.sampleRate
    )
    let filteredEvents = filter(events, with: options)
    let report = EventReport(
        schemaVersion: "1.1",
        generatedAt: Date(),
        sourceFile: inspection.fileURL.lastPathComponent,
        session: SessionReport(
            packetCount: inspection.packetCount,
            sampleRateHz: inspection.header.sampleRate,
            durationSeconds: inspection.duration,
            vehicleCode: inspection.vehicleCode,
            lapRange: inspection.lapRange.map { LapRangeReport(minimum: $0.lowerBound, maximum: $0.upperBound) },
            phases: inspection.phases.map(String.init(describing:)).sorted(),
            invalidPacketCount: inspection.invalidPacketCount,
            sequenceGapCount: inspection.sequenceGapCount,
            speedMetersPerSecond: RangeReport(inspection.speed),
            steeringAngle: RangeReport(inspection.steeringAngle),
            throttle: RangeReport(inspection.throttle),
            brake: RangeReport(inspection.brake),
            engineRPM: RangeReport(inspection.engineRPM),
            tireSurfaceTemperature: RangeReport(inspection.tireSurfaceTemperature),
            suspensionTravel: RangeReport(inspection.suspensionTravel),
            accelerationMagnitudeG: RangeReport(inspection.accelerationMagnitudeG),
            lateralCentripetalG: RangeReport(inspection.lateralCentripetalG),
            derivedAccelerationSampleCount: inspection.derivedAccelerationSampleCount,
            peakAccelerationEvent: inspection.peakAccelerationEvent.map(DerivedEventReport.init),
            peakLateralCentripetalEvent: inspection.peakLateralCentripetalEvent.map(DerivedEventReport.init)
        ),
        detector: DetectorReport(
            eventKinds: TelemetryEventKind.allCases.map(\.rawValue),
            groupingIntervalSeconds: configuration.groupingInterval
        ),
        query: queryReport(for: options),
        events: filteredEvents.map(EventReportItem.init),
        cornerPerformanceWindows: cornerWindows.map(CornerPerformanceReport.init)
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    try encoder.encode(report).write(to: options.outputURL, options: .atomic)
    print("report_written: \(options.outputURL.path)")
    print("detected_event_count: \(events.count)")
    print("reported_event_count: \(filteredEvents.count)")
    if let textOutputURL = options.textOutputURL {
        try makeTextReport(from: report).write(to: textOutputURL, atomically: true, encoding: .utf8)
        print("text_report_written: \(textOutputURL.path)")
    }
} catch {
    FileHandle.standardError.write(Data("inspection_failed: \(error)\n".utf8))
    exit(EXIT_FAILURE)
}

private func printUsageAndExit() -> Never {
    print("""
    Usage:
      TelemetryKitInspector <session.race> [options]

    Options:
      --output <path.json>       Write to a specific JSON path.
      --lap <number>             Include events from one lap.
      --between <start> <end>   Include events in lap-time seconds.
      --kind <eventKind>         Include events containing a kind.
      --near <lap> <seconds>     Include events near a lap time.
      --tolerance <seconds>      Tolerance for --near (default: 3).
    --text <path.txt>          Also write a human-readable report.

    Examples:
      TelemetryKitInspector session.race --lap 3
      TelemetryKitInspector session.race --lap 3 --between 0 20 --output lap-3.json
      TelemetryKitInspector session.race --kind rapidRotation
      TelemetryKitInspector session.race --near 2 34
    TelemetryKitInspector session.race --text events.txt
    """)
    exit(EXIT_FAILURE)
}

private enum InspectorArgumentError: Error, CustomStringConvertible {
    case missingValue(String)
    case invalidValue(String)
    case unknownOption(String)

    var description: String {
        switch self {
        case .missingValue(let option): return "Missing value for \(option)"
        case .invalidValue(let message): return message
        case .unknownOption(let option): return "Unknown option \(option)"
        }
    }
}

private func parseOptions(_ arguments: [String], sourceURL: URL) throws -> QueryOptions {
    var lap: Int?
    var range: ClosedRange<TimeInterval>?
    var kind: String?
    var nearLap: Int?
    var nearTime: TimeInterval?
    var nearTolerance: TimeInterval = 3
    var outputURL = sourceURL.deletingPathExtension().appendingPathExtension("events.json")
    var textOutputURL: URL?
    var index = 0

    while index < arguments.count {
        switch arguments[index] {
        case "--output":
            index += 1
            guard index < arguments.count else { throw InspectorArgumentError.missingValue("--output") }
            outputURL = URL(fileURLWithPath: arguments[index])
        case "--lap":
            index += 1
            lap = try integerValue(arguments, at: index, option: "--lap")
        case "--between":
            let startIndex = index + 1
            let endIndex = index + 2
            guard endIndex < arguments.count,
                  let start = Double(arguments[startIndex]),
                  let end = Double(arguments[endIndex]),
                  start <= end else {
                throw InspectorArgumentError.invalidValue("--between requires start and end seconds")
            }
            range = start...end
            index = endIndex
        case "--kind":
            index += 1
            guard index < arguments.count else { throw InspectorArgumentError.missingValue("--kind") }
            kind = arguments[index]
        case "--near":
            let lapIndex = index + 1
            let timeIndex = index + 2
            guard timeIndex < arguments.count,
                  let eventLap = Int(arguments[lapIndex]),
                  let eventTime = Double(arguments[timeIndex]) else {
                throw InspectorArgumentError.invalidValue("--near requires lap and seconds")
            }
            nearLap = eventLap
            nearTime = eventTime
            index = timeIndex
        case "--tolerance":
            index += 1
            guard index < arguments.count,
                  let tolerance = Double(arguments[index]),
                  tolerance >= 0 else {
                throw InspectorArgumentError.invalidValue("--tolerance requires non-negative seconds")
            }
            nearTolerance = tolerance
        case "--text":
            index += 1
            guard index < arguments.count else { throw InspectorArgumentError.missingValue("--text") }
            textOutputURL = URL(fileURLWithPath: arguments[index])
        case "--help", "-h":
            printUsageAndExit()
        default:
            throw InspectorArgumentError.unknownOption(arguments[index])
        }
        index += 1
    }

    return QueryOptions(
        lap: lap,
        range: range,
        kind: kind,
        nearLap: nearLap,
        nearTime: nearTime,
        nearTolerance: nearTolerance,
        outputURL: outputURL,
        textOutputURL: textOutputURL
    )
}

private func integerValue(_ arguments: [String], at index: Int, option: String) throws -> Int {
    guard index < arguments.count, let value = Int(arguments[index]) else {
        throw InspectorArgumentError.invalidValue("\(option) requires an integer")
    }
    return value
}

private func filter(_ events: [TelemetryEvent], with options: QueryOptions) -> [TelemetryEvent] {
    events.filter { event in
        if let lap = options.lap, event.lapNumber != lap { return false }
        if let range = options.range {
            guard let lapTime = event.lapTime, range.contains(lapTime) else { return false }
        }
        if let kind = options.kind, !event.kinds.contains(where: { $0.rawValue == kind }) { return false }
        if let nearLap = options.nearLap, event.lapNumber != nearLap { return false }
        if let nearTime = options.nearTime {
            guard let lapTime = event.lapTime,
                  abs(lapTime - nearTime) <= options.nearTolerance else { return false }
        }
        return true
    }
}

private func queryReport(for options: QueryOptions) -> QueryReport? {
    guard options.lap != nil || options.range != nil || options.kind != nil || options.nearLap != nil else {
        return nil
    }
    return QueryReport(
        lap: options.lap,
        rangeStartSeconds: options.range?.lowerBound,
        rangeEndSeconds: options.range?.upperBound,
        kind: options.kind,
        nearLap: options.nearLap,
        nearTimeSeconds: options.nearTime,
        nearToleranceSeconds: options.nearTime == nil ? nil : options.nearTolerance
    )
}

private func makeTextReport(from report: EventReport) -> String {
    var lines = [
        "Telemetry Inspection Report",
        "============================",
        "",
        "Source: \(report.sourceFile)",
        "Packets: \(report.session.packetCount)",
        "Sample rate: \(report.session.sampleRateHz) Hz",
        "Duration: \(formatTime(report.session.durationSeconds))",
        "Vehicle code: \(report.session.vehicleCode.map { String($0) } ?? "unknown")",
        "",
        "Detected events: \(report.events.count)",
        ""
    ]

    for (index, event) in report.events.enumerated() {
        lines.append("Event \(index + 1)")
        lines.append("  kinds: \(event.kinds.joined(separator: ", "))")
        lines.append("  lap: \(event.lapNumber)")
        lines.append("  lap time: \(event.lapTimeSeconds.map(formatTime) ?? "unavailable")")
        lines.append("  session time: \(formatTime(event.peakTimeSeconds))")
        lines.append("  interval: \(formatTime(event.startTimeSeconds)) - \(formatTime(event.endTimeSeconds))")
        lines.append("  confidence: \(event.confidence)")
        lines.append("  speed before / after: \(event.speedBeforeMetersPerSecond) / \(event.speedAfterMetersPerSecond) m/s")
        lines.append("  gear before / at peak: \(event.gearBefore) / \(event.gearAtPeak)")
        lines.append("  throttle / brake at peak: \(event.throttleAtPeak) / \(event.brakeAtPeak)")
        lines.append("  peak yaw rate: \(event.peakYawRateRadiansPerSecond) rad/s")
        lines.append("  peak lateral centripetal estimate: \(event.peakLateralCentripetalG) G")
        lines.append("  peak wheel-speed spread ratio: \(event.peakWheelSpeedSpreadRatio)")
        lines.append("")
    }

    lines.append("Corner performance windows: \(report.cornerPerformanceWindows.count)")
    lines.append("")
    for (index, window) in report.cornerPerformanceWindows.enumerated() {
        lines.append("Corner window \(index + 1)")
        lines.append("  lap: \(window.lapNumber)")
        lines.append("  anchor lap time: \(window.anchorLapTimeSeconds.map(formatTime) ?? "unavailable")")
        lines.append("  anchor session time: \(formatTime(window.anchorSessionTimeSeconds))")
        lines.append("  possible corner: \(window.isPossibleCorner ? "yes" : "no")")
        lines.append("  entry lap time: \(window.entryLapTimeSeconds.map(formatTime) ?? "unavailable")")
        lines.append("  entry session time: \(formatTime(window.entrySessionTimeSeconds))")
        lines.append("  entry speed / gear / brake: \(window.entrySpeedMetersPerSecond) m/s, gear \(window.entryGear), brake \(window.entryBrake)")
        lines.append("  minimum-speed lap time: \(window.minimumSpeedLapTimeSeconds.map(formatTime) ?? "unavailable")")
        lines.append("  minimum-speed session time: \(formatTime(window.minimumSpeedSessionTimeSeconds))")
        lines.append("  minimum speed / gear: \(window.minimumSpeedMetersPerSecond) m/s, gear \(window.minimumSpeedGear)")
        lines.append("  peak lateral centripetal estimate: \(window.peakLateralCentripetalG) G")
        lines.append("  throttle pickup lap time: \(window.throttlePickupLapTimeSeconds.map(formatTime) ?? "not observed")")
        lines.append("  throttle pickup session time: \(window.throttlePickupSessionTimeSeconds.map(formatTime) ?? "not observed")")
        lines.append("  exit lap time: \(window.exitLapTimeSeconds.map(formatTime) ?? "unavailable")")
        lines.append("  exit session time: \(formatTime(window.exitSessionTimeSeconds))")
        lines.append("  exit speed / gear / throttle: \(window.exitSpeedMetersPerSecond) m/s, gear \(window.exitGear), throttle \(window.exitThrottle)")
        lines.append("  speed recovery: \(window.speedRecoveryMetersPerSecond) m/s")
        lines.append("")
    }

    return lines.joined(separator: "\n")
}

private func formatTime(_ seconds: TimeInterval) -> String {
    let totalSeconds = max(0, Int(seconds.rounded()))
    return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
}

private func lapTime(
    anchorLapTime: TimeInterval?,
    anchorSessionTime: TimeInterval,
    targetSessionTime: TimeInterval
) -> TimeInterval? {
    guard let anchorLapTime else { return nil }
    return anchorLapTime + (targetSessionTime - anchorSessionTime)
}

private func loadPackets(from fileURL: URL, header: RaceFileHeader) throws -> [TelemetryPacket] {
    let handle = try FileHandle(forReadingFrom: fileURL)
    defer { try? handle.close() }
    try handle.seek(toOffset: UInt64(RaceFileHeader.headerSize))

    var packets: [TelemetryPacket] = []
    let packetSize = Int(header.packetSize)
    while let frame = try handle.read(upToCount: packetSize), !frame.isEmpty {
        guard frame.count == packetSize else { break }
        let packet = GT7Packet(decryptedData: frame)
        if packet.magic == 0x47375330 {
            packets.append(packet)
        }
    }
    return packets
}
