import Foundation
import TelemetryKit

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("Usage: TelemetryKitInspector <path-to-race-file>\n".utf8))
    exit(EXIT_FAILURE)
}

let fileURL = URL(fileURLWithPath: CommandLine.arguments[1])

do {
    let inspection = try RecordedSessionInspector().inspect(fileURL: fileURL)
    print("file: \(inspection.fileURL.path)")
    print("header: version=\(inspection.header.version), packetSize=\(inspection.header.packetSize), sampleRate=\(inspection.header.sampleRate)")
    print("packets: \(inspection.packetCount)")
    print("duration_seconds: \(inspection.duration)")
    let vehicleCode = inspection.vehicleCode.map { String($0) } ?? "unknown"
    let laps = inspection.lapRange.map { "\($0.lowerBound)-\($0.upperBound)" } ?? "unknown"
    print("vehicle_code: \(vehicleCode)")
    print("laps: \(laps)")
    print("phases: \(inspection.phases.map(String.init(describing:)).sorted().joined(separator: ", "))")
    printRange("speed_mps", inspection.speed)
    printRange("steering_angle", inspection.steeringAngle)
    printRange("throttle", inspection.throttle)
    printRange("brake", inspection.brake)
    printRange("engine_rpm", inspection.engineRPM)
    printRange("tire_surface_temperature", inspection.tireSurfaceTemperature)
    printRange("suspension_travel", inspection.suspensionTravel)
    printRange("g_force", inspection.gForce)
    print("invalid_packets: \(inspection.invalidPacketCount)")
    print("sequence_gap_count: \(inspection.sequenceGapCount)")
} catch {
    FileHandle.standardError.write(Data("inspection_failed: \(error)\n".utf8))
    exit(EXIT_FAILURE)
}

private func printRange(_ name: String, _ range: TelemetryRange) {
    let minimum = range.minimum.map { String($0) } ?? "unknown"
    let maximum = range.maximum.map { String($0) } ?? "unknown"
    print("\(name): min=\(minimum), max=\(maximum)")
}