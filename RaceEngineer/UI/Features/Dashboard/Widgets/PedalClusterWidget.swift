//
//  PedalClusterWidget.swift
//  RaceEngineer
//
//  Created on 8/16/26.
//

import SwiftUI

/// Pure presentational driver input meters for Throttle, Brake, and Clutch.
public struct PedalClusterWidget: View {
    public let inputs: DriverInputState

    public init(inputs: DriverInputState) {
        self.inputs = inputs
    }

    public var body: some View {
        VStack(spacing: 8) {
            Text("PEDAL INPUTS")
                .font(TelemetryTypography.label)
                .foregroundColor(TelemetryColors.mutedText)

            HStack(spacing: 14) {
                // Clutch
                PedalColumn(
                    label: "CLUTCH",
                    shortLabel: "C",
                    value: inputs.clutch,
                    color: TelemetryColors.clutch
                )

                // Brake
                PedalColumn(
                    label: "BRAKE",
                    shortLabel: "B",
                    value: inputs.brake,
                    color: TelemetryColors.brake
                )

                // Throttle
                PedalColumn(
                    label: "THROTTLE",
                    shortLabel: "T",
                    value: inputs.throttle,
                    color: TelemetryColors.throttle
                )
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

// MARK: - Subcomponents

private struct PedalColumn: View {
    let label: String
    let shortLabel: String
    let value: Float
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            LinearMeter(
                value: value,
                orientation: .vertical,
                fillColor: color,
                trackColor: TelemetryColors.surfaceSecondary,
                cornerRadius: 3
            )
            .frame(width: 16, height: 70)

            Text(shortLabel)
                .font(TelemetryTypography.label)
                .foregroundColor(TelemetryColors.brightText)

            Text("\(Int(value * 100))%")
                .font(TelemetryTypography.unit)
                .foregroundColor(TelemetryColors.mutedText)
                .telemetryMonospacedDigits()
        }
    }
}

#Preview("Pedals - Idle") {
    PedalClusterWidget(inputs: .idle)
        .padding()
        .background(Color.black)
}

#Preview("Pedals - Full Throttle") {
    PedalClusterWidget(inputs: .fullThrottle)
        .padding()
        .background(Color.black)
}

#Preview("Pedals - Trail Braking") {
    PedalClusterWidget(inputs: .trailBraking)
        .padding()
        .background(Color.black)
}
