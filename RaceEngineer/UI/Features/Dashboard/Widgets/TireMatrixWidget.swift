//
//  TireMatrixWidget.swift
//  RaceEngineer
//
//  Created on 8/16/26.
//

import SwiftUI
import TelemetryKit

/// Pure presentational 4-corner tire matrix displaying thermal heatmaps and surface temperatures.
public struct TireMatrixWidget: View {
    public let tires: TireState

    public init(tires: TireState) {
        self.tires = tires
    }

    public var body: some View {
        VStack(spacing: 8) {
            Text("TIRE THERMALS (°C)")
                .font(TelemetryTypography.label)
                .foregroundColor(TelemetryColors.mutedText)

            HStack(spacing: 12) {
                // Front Axle
                VStack(spacing: 8) {
                    TireBadge(label: "FL", temp: tires.surfaceTemps.frontLeft)
                    TireBadge(label: "RL", temp: tires.surfaceTemps.rearLeft)
                }

                // Chassis center indicator
                ChassisIndicator()

                // Rear Axle
                VStack(spacing: 8) {
                    TireBadge(label: "FR", temp: tires.surfaceTemps.frontRight)
                    TireBadge(label: "RR", temp: tires.surfaceTemps.rearRight)
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

// MARK: - Subcomponents

private struct TireBadge: View {
    let label: String
    let temp: Float

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(TelemetryTypography.unit)
                .foregroundColor(TelemetryColors.mutedText)

            Text("\(Int(temp))°")
                .font(TelemetryTypography.compactValue)
                .foregroundColor(TelemetryColors.brightText)
                .telemetryMonospacedDigits()
        }
        .frame(width: 44, height: 48)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(TelemetryColors.tireThermalColor(celsius: temp))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

private struct ChassisIndicator: View {
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "triangle.fill")
                .font(.system(size: 8))
                .foregroundColor(TelemetryColors.mutedText)
            
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(TelemetryColors.cardBorder, lineWidth: 1)
                .frame(width: 16, height: 64)
        }
    }
}

#Preview("Tires - Cold") {
    TireMatrixWidget(tires: .cold)
        .padding()
        .background(Color.black)
}

#Preview("Tires - Optimal") {
    TireMatrixWidget(tires: .optimal)
        .padding()
        .background(Color.black)
}

#Preview("Tires - Overheating") {
    TireMatrixWidget(tires: .overheating)
        .padding()
        .background(Color.black)
}
