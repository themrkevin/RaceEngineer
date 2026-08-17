//
//  LapTimingWidget.swift
//  RaceEngineer
//
//  Created on 8/16/26.
//

import SwiftUI

/// Pure presentational widget for lap numbers, race position, and session delta timing.
public struct LapTimingWidget: View {
    public let timing: LapTimingState

    public init(timing: LapTimingState) {
        self.timing = timing
    }

    private func formatLapTime(_ interval: TimeInterval?) -> String {
        guard let interval, interval > 0 else { return "--:--.---" }
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        let millis = Int((interval.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d.%03d", minutes, seconds, millis)
    }

    public var body: some View {
        HStack(spacing: 16) {
            // Lap Number
            VStack(spacing: 2) {
                Text("LAP")
                    .font(TelemetryTypography.label)
                    .foregroundColor(TelemetryColors.mutedText)

                Text("\(timing.currentLapNumber)")
                    .font(TelemetryTypography.timingValue)
                    .foregroundColor(TelemetryColors.brightText)
                    .telemetryMonospacedDigits()
            }
            .frame(minWidth: 50)

            // Race Position
            if timing.racePosition > 0 {
                VStack(spacing: 2) {
                    Text("POS")
                        .font(TelemetryTypography.label)
                        .foregroundColor(TelemetryColors.mutedText)

                    Text("P\(timing.racePosition)")
                        .font(TelemetryTypography.timingValue)
                        .foregroundColor(.yellow)
                        .telemetryMonospacedDigits()
                }
                .frame(minWidth: 50)
            }

            Spacer()

            // Lap Times Column
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 6) {
                    Text("LAST")
                        .font(TelemetryTypography.unit)
                        .foregroundColor(TelemetryColors.mutedText)
                    Text(formatLapTime(timing.lastLapTime))
                        .font(TelemetryTypography.compactValue)
                        .foregroundColor(TelemetryColors.brightText)
                        .telemetryMonospacedDigits()
                }

                HStack(spacing: 6) {
                    Text("BEST")
                        .font(TelemetryTypography.unit)
                        .foregroundColor(TelemetryColors.mutedText)
                    Text(formatLapTime(timing.bestLapTime))
                        .font(TelemetryTypography.compactValue)
                        .foregroundColor(.purple)
                        .telemetryMonospacedDigits()
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(TelemetryColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(TelemetryColors.cardBorder, lineWidth: 1)
                )
        )
    }
}

#Preview("Lap Timing - Racing") {
    LapTimingWidget(timing: .racing)
        .padding()
        .background(Color.black)
}

#Preview("Lap Timing - Empty") {
    LapTimingWidget(timing: .empty)
        .padding()
        .background(Color.black)
}
