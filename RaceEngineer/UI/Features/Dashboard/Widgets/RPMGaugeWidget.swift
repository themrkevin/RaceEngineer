//
//  RPMGaugeWidget.swift
//  RaceEngineer
//
//  Created on 8/16/26.
//

import SwiftUI

/// Pure presentational RPM bar with staged shift lights and redline warning.
public struct RPMGaugeWidget: View {
    public let engine: EngineState

    public init(engine: EngineState) {
        self.engine = engine
    }

    public var body: some View {
        VStack(spacing: 6) {
            // Header: Label and Exact RPM Readout
            HStack {
                Text("ENGINE RPM")
                    .font(TelemetryTypography.label)
                    .foregroundColor(TelemetryColors.mutedText)
                Spacer()
                Text("\(Int(engine.rpm))")
                    .font(TelemetryTypography.secondaryValue)
                    .foregroundColor(engine.isShiftLightActive ? .blue : TelemetryColors.brightText)
                    .telemetryMonospacedDigits()
            }

            // Gauge Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(TelemetryColors.surfaceSecondary)

                    // Active RPM fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(TelemetryColors.rpmColor(percent: engine.rpmPercent))
                        .frame(width: geo.size.width * CGFloat(engine.rpmPercent))

                    // Shift Light Flash Overlay
                    if engine.isShiftLightActive {
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Color.blue, lineWidth: 2)
                            .background(Color.blue.opacity(0.3))
                    }
                }
            }
            .frame(height: 24)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(TelemetryColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(TelemetryColors.cardBorder, lineWidth: 1)
                )
        )
    }
}

#Preview("RPM - Idle") {
    RPMGaugeWidget(engine: .idle)
        .padding()
        .background(Color.black)
}

#Preview("RPM - Racing") {
    RPMGaugeWidget(engine: .racing)
        .padding()
        .background(Color.black)
}

#Preview("RPM - Shift Alert") {
    RPMGaugeWidget(engine: .shiftAlert)
        .padding()
        .background(Color.black)
}
