//
//  MetricCard.swift
//  RaceEngineer
//
//  Created on 8/16/26.
//

import SwiftUI

/// Pure presentational card displaying a telemetry label, numerical value, unit, and optional alert state.
public struct MetricCard: View {
    public let label: String
    public let valueText: String
    public let unitText: String?
    public let valueColor: Color
    public let isAlert: Bool

    public init(
        label: String,
        valueText: String,
        unitText: String? = nil,
        valueColor: Color = TelemetryColors.brightText,
        isAlert: Bool = false
    ) {
        self.label = label
        self.valueText = valueText
        self.unitText = unitText
        self.valueColor = valueColor
        self.isAlert = isAlert
    }

    public var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(TelemetryTypography.label)
                .foregroundColor(TelemetryColors.mutedText)

            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(valueText)
                    .font(TelemetryTypography.primaryValue)
                    .foregroundColor(isAlert ? Color.red : valueColor)
                    .telemetryMonospacedDigits()

                if let unitText {
                    Text(unitText)
                        .font(TelemetryTypography.unit)
                        .foregroundColor(TelemetryColors.mutedText)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isAlert ? Color.red.opacity(0.15) : TelemetryColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(isAlert ? Color.red.opacity(0.6) : TelemetryColors.cardBorder, lineWidth: 1)
                )
        )
    }
}

#Preview("MetricCard Variants") {
    HStack(spacing: 12) {
        MetricCard(label: "OIL TEMP", valueText: "98", unitText: "°C")
        MetricCard(label: "WATER", valueText: "115", unitText: "°C", isAlert: true)
        MetricCard(label: "BOOST", valueText: "1.42", unitText: "BAR")
    }
    .padding()
    .background(Color.black)
}
