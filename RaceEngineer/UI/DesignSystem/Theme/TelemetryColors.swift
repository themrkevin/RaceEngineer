//
//  TelemetryColors.swift
//  RaceEngineer
//
//  Created on 8/16/26.
//

import SwiftUI

public enum TelemetryColors {
    // MARK: - Core Theme Surfaces
    public static let background = Color.black
    public static let surface = Color(white: 0.08)
    public static let surfaceSecondary = Color(white: 0.14)
    public static let cardBorder = Color(white: 0.20)
    public static let mutedText = Color(white: 0.55)
    public static let brightText = Color.white

    // MARK: - Driver Input Colors
    public static let throttle = Color.green
    public static let brake = Color.red
    public static let clutch = Color.blue
    public static let steering = Color.yellow

    // MARK: - RPM & Shift Lights
    public static func rpmColor(percent: Float) -> Color {
        if percent >= 0.95 {
            return Color.blue // Flash / Shift light indicator
        } else if percent >= 0.85 {
            return Color.red
        } else if percent >= 0.70 {
            return Color.yellow
        } else {
            return Color.green
        }
    }

    // MARK: - Tire Thermal Gradient
    /// Maps surface temperature in Celsius to thermal heatmap color.
    public static func tireThermalColor(celsius: Float) -> Color {
        switch celsius {
        case ..<65:
            return Color(red: 0.15, green: 0.45, blue: 0.95) // Cold (Blue)
        case 65..<75:
            return Color(red: 0.10, green: 0.75, blue: 0.65) // Warming up (Cyan/Teal)
        case 75..<95:
            return Color(red: 0.15, green: 0.85, blue: 0.25) // Optimal Grip (Green)
        case 95..<105:
            return Color(red: 0.95, green: 0.75, blue: 0.10) // Hot (Yellow)
        case 105..<115:
            return Color(red: 0.95, green: 0.40, blue: 0.10) // Very Hot (Orange)
        default:
            return Color(red: 0.95, green: 0.15, blue: 0.15) // Overheating / Blistering (Red)
        }
    }

    // MARK: - Fluid Status Colors
    public static func oilTempColor(celsius: Float) -> Color {
        if celsius < 70 { return Color.blue }
        if celsius > 120 { return Color.red }
        return Color.white
    }

    public static func waterTempColor(celsius: Float) -> Color {
        if celsius < 70 { return Color.blue }
        if celsius > 105 { return Color.red }
        return Color.white
    }
}
