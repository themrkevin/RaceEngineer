//
//  FluidTempsWidget.swift
//  RaceEngineer
//
//  Created on 8/16/26.
//

import SwiftUI

/// Pure presentational widget displaying powertrain fluid temperatures (Oil, Water) and Fuel status.
public struct FluidTempsWidget: View {
    public let engine: EngineState

    public init(engine: EngineState) {
        self.engine = engine
    }

    private var isFuelLow: Bool {
        engine.fuelPercent < 0.15 && engine.fuelCapacity > 0
    }

    public var body: some View {
        VStack(spacing: 8) {
            Text("FLUIDS & FUEL")
                .font(TelemetryTypography.label)
                .foregroundColor(TelemetryColors.mutedText)

            HStack(spacing: 10) {
                // Oil Temp
                MetricCard(
                    label: "OIL",
                    valueText: "\(Int(engine.oilTemp))",
                    unitText: "°C",
                    valueColor: TelemetryColors.oilTempColor(celsius: engine.oilTemp),
                    isAlert: engine.oilTemp > 125
                )

                // Water Temp
                MetricCard(
                    label: "H2O",
                    valueText: "\(Int(engine.waterTemp))",
                    unitText: "°C",
                    valueColor: TelemetryColors.waterTempColor(celsius: engine.waterTemp),
                    isAlert: engine.waterTemp > 110
                )

                // Fuel Gauge Column
                VStack(spacing: 3) {
                    Text("FUEL")
                        .font(TelemetryTypography.label)
                        .foregroundColor(isFuelLow ? Color.red : TelemetryColors.mutedText)

                    LinearMeter(
                        value: engine.fuelPercent,
                        orientation: .vertical,
                        fillColor: isFuelLow ? Color.red : Color.white,
                        trackColor: TelemetryColors.surfaceSecondary,
                        cornerRadius: 2
                    )
                    .frame(width: 18, height: 32)

                    Text("\(Int(engine.fuelPercent * 100))%")
                        .font(TelemetryTypography.unit)
                        .foregroundColor(isFuelLow ? Color.red : TelemetryColors.mutedText)
                        .telemetryMonospacedDigits()
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(TelemetryColors.surfaceSecondary)
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

#Preview("Fluids - Normal") {
    FluidTempsWidget(engine: .racing)
        .padding()
        .background(Color.black)
}

#Preview("Fluids - Overheating & Low Fuel") {
    FluidTempsWidget(engine: .overheating)
        .padding()
        .background(Color.black)
}
