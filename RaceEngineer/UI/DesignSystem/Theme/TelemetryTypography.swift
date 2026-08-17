//
//  TelemetryTypography.swift
//  RaceEngineer
//
//  Created on 8/16/26.
//

import SwiftUI

public enum TelemetryTypography {
    // MARK: - Numerical HUD Typography (Strictly Monospaced Digits)
    
    /// Giant speed readout (90pt bold monospaced)
    public static let speedDisplay = Font.system(size: 90, weight: .black, design: .monospaced)
    
    /// Prominent gear indicator (64pt black rounded)
    public static let gearDisplay = Font.system(size: 64, weight: .black, design: .rounded)
    
    /// Primary readout value (24pt bold monospaced)
    public static let primaryValue = Font.system(size: 24, weight: .bold, design: .monospaced)
    
    /// Secondary readout value (16pt bold monospaced)
    public static let secondaryValue = Font.system(size: 16, weight: .bold, design: .monospaced)
    
    /// Lap timing & position font (20pt bold monospaced)
    public static let timingValue = Font.system(size: 20, weight: .bold, design: .monospaced)
    
    /// Mini readout for tire temperatures & compact metrics (11pt bold monospaced)
    public static let compactValue = Font.system(size: 11, weight: .bold, design: .monospaced)
    
    // MARK: - Metric Labels
    
    /// Standard section header / HUD label (10pt bold uppercase)
    public static let label = Font.system(size: 10, weight: .bold, design: .monospaced)
    
    /// Sub-label / unit descriptor (9pt medium uppercase)
    public static let unit = Font.system(size: 9, weight: .semibold, design: .monospaced)
}

// MARK: - View Modifier Extensions

public extension View {
    /// Forces monospaced digits to prevent layout jitter in 60Hz telemetry loops.
    func telemetryMonospacedDigits() -> some View {
        self.monospacedDigit()
    }
}
