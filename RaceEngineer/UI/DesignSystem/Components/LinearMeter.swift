//
//  LinearMeter.swift
//  RaceEngineer
//
//  Created on 8/16/26.
//

import SwiftUI

public enum MeterOrientation {
    case vertical
    case horizontal
}

/// Pure presentational progress bar supporting vertical and horizontal orientations with zero heap allocations.
public struct LinearMeter: View {
    public let value: Float // Normalized 0.0 - 1.0
    public let orientation: MeterOrientation
    public let fillColor: Color
    public let trackColor: Color
    public let cornerRadius: CGFloat

    public init(
        value: Float,
        orientation: MeterOrientation = .vertical,
        fillColor: Color = .white,
        trackColor: Color = Color.white.opacity(0.12),
        cornerRadius: CGFloat = 3
    ) {
        self.value = min(max(value, 0.0), 1.0)
        self.orientation = orientation
        self.fillColor = fillColor
        self.trackColor = trackColor
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: orientation == .vertical ? .bottom : .leading) {
                // Background Track
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(trackColor)

                // Active Fill
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(fillColor)
                    .frame(
                        width: orientation == .vertical ? geo.size.width : geo.size.width * CGFloat(value),
                        height: orientation == .vertical ? geo.size.height * CGFloat(value) : geo.size.height
                    )
            }
        }
    }
}

#Preview("LinearMeter States") {
    HStack(spacing: 20) {
        LinearMeter(value: 0.25, orientation: .vertical, fillColor: .green)
            .frame(width: 14, height: 100)
        LinearMeter(value: 0.75, orientation: .vertical, fillColor: .red)
            .frame(width: 14, height: 100)
        LinearMeter(value: 1.00, orientation: .vertical, fillColor: .blue)
            .frame(width: 14, height: 100)
    }
    .padding()
    .background(Color.black)
}
