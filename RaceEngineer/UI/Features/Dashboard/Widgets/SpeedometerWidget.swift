//
//  SpeedometerWidget.swift
//  RaceEngineer
//
//  Created on 8/16/26.
//

import SwiftUI

/// Pure presentational HUD showing large-format vehicle speed and transmission gear.
public struct SpeedometerWidget: View {
    public let motion: MotionState

    public init(motion: MotionState) {
        self.motion = motion
    }

    private var gearText: String {
        switch motion.gear {
        case 0: return "N"
        case -1: return "R"
        default: return "\(motion.gear)"
        }
    }

    private var gearColor: Color {
        switch motion.gear {
        case 0: return .green
        case -1: return .red
        default: return TelemetryColors.brightText
        }
    }

    public var body: some View {
        HStack(spacing: 16) {
            // Speed Column
            VStack(alignment: .leading, spacing: 0) {
                Text("SPEED")
                    .font(TelemetryTypography.label)
                    .foregroundColor(TelemetryColors.mutedText)

                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text("\(Int(motion.speedMph))")
                        .font(TelemetryTypography.speedDisplay)
                        .foregroundColor(TelemetryColors.brightText)
                        .telemetryMonospacedDigits()

                    VStack(alignment: .leading, spacing: 2) {
                        Text("MPH")
                            .font(TelemetryTypography.primaryValue)
                            .foregroundColor(TelemetryColors.mutedText)

                        Text("\(Int(motion.speedKmh)) KM/H")
                            .font(TelemetryTypography.unit)
                            .foregroundColor(TelemetryColors.mutedText.opacity(0.8))
                            .telemetryMonospacedDigits()
                    }
                }
            }

            Spacer()

            // Gear Column
            VStack(spacing: 2) {
                Text("GEAR")
                    .font(TelemetryTypography.label)
                    .foregroundColor(TelemetryColors.mutedText)

                Text(gearText)
                    .font(TelemetryTypography.gearDisplay)
                    .foregroundColor(gearColor)
                    .frame(minWidth: 70, minHeight: 70)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(TelemetryColors.surfaceSecondary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(TelemetryColors.cardBorder, lineWidth: 1)
                            )
                    )

                if motion.suggestedGear > 0 && motion.suggestedGear != motion.gear {
                    Text("SUGG: \(motion.suggestedGear)")
                        .font(TelemetryTypography.unit)
                        .foregroundColor(.yellow)
                        .telemetryMonospacedDigits()
                } else {
                    Text(" ")
                        .font(TelemetryTypography.unit)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(TelemetryColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(TelemetryColors.cardBorder, lineWidth: 1)
                )
        )
    }
}

#Preview("Speedometer - Idle") {
    SpeedometerWidget(motion: .idle)
        .padding()
        .background(Color.black)
}

#Preview("Speedometer - Racing") {
    SpeedometerWidget(motion: .racing)
        .padding()
        .background(Color.black)
}

#Preview("Speedometer - Suggested Shift") {
    SpeedometerWidget(motion: .shiftSuggested)
        .padding()
        .background(Color.black)
}
