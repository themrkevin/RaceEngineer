import SwiftUI
import TelemetryKit

/// Container View (Smart Coordinator) that connects to `TelemetryViewModel` and passes
/// immutable value slices down to pure presentational widgets.
@MainActor
public struct DashboardView: View {
    @Bindable public var viewModel: TelemetryViewModel

    public init(viewModel: TelemetryViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                TelemetryColors.background
                    .ignoresSafeArea()

                let isLandscape = geometry.size.width > geometry.size.height

                if isLandscape {
                    landscapeLayout
                } else {
                    portraitLayout
                }

                if viewModel.sessionPhase != .driving {
                    sessionPhaseBanner
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
            }
        }
    }

    private var sessionPhaseBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: sessionPhaseIcon)
            Text(sessionPhaseTitle)
                .font(TelemetryTypography.label)
        }
        .foregroundStyle(sessionPhaseColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(sessionPhaseColor.opacity(0.12))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(sessionPhaseColor.opacity(0.35), lineWidth: 1))
    }

    private var sessionPhaseTitle: String {
        switch viewModel.sessionPhase {
        case .loading: return "PREPARING SESSION"
        case .preSession: return "AWAITING START"
        case .paused: return "PAUSED"
        case .driving: return ""
        }
    }

    private var sessionPhaseIcon: String {
        switch viewModel.sessionPhase {
        case .loading: return "hourglass"
        case .preSession: return "flag"
        case .paused: return "pause.fill"
        case .driving: return ""
        }
    }

    private var sessionPhaseColor: Color {
        switch viewModel.sessionPhase {
        case .loading: return .yellow
        case .preSession: return .orange
        case .paused: return .yellow
        case .driving: return .green
        }
    }

    // MARK: - Portrait Layout

    private var portraitLayout: some View {
        VStack(spacing: 16) {
            // Header Bar with Recording Controls
            headerBar

            // Recording Status Banner (Visible when recording is active or paused)
            if viewModel.isRecording {
                recordingStatusBanner
            }

            // RPM Gauge Widget (60Hz shift light)
            RPMGaugeWidget(engine: viewModel.engine)

            // Speed & Gear Widget
            SpeedometerWidget(motion: viewModel.motion)

            // Lap Timing & Session Widget
            LapTimingWidget(timing: viewModel.timing)

            Spacer()

            // Bottom 3-Column Telemetry Matrix
            HStack(alignment: .top, spacing: 12) {
                TireMatrixWidget(tires: viewModel.tires)
                    .frame(maxWidth: .infinity)

                PedalClusterWidget(inputs: viewModel.inputs)
                    .frame(maxWidth: .infinity)

                FluidTempsWidget(engine: viewModel.engine)
                    .frame(maxWidth: .infinity)
            }
            .padding(.bottom, 10)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Landscape Cockpit Layout (Sim-Rig Mounting)

    private var landscapeLayout: some View {
        VStack(spacing: 12) {
            // Top Bar: RPM Gauge & Cockpit Controls
            HStack(spacing: 12) {
                RPMGaugeWidget(engine: viewModel.engine)

                // Recording & Disconnect Control Strip
                HStack(spacing: 8) {
                    // autoRecordToggle
                    manualRecordButton

                    // Disconnect Button
                    Button(action: { viewModel.disconnect() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(TelemetryColors.mutedText)
                    }
                }
                .padding(.trailing, 4)
            }

            // Center Cockpit Grid
            HStack(alignment: .center, spacing: 14) {
                // Left Wing: Tires & Fluids
                VStack(spacing: 10) {
                    TireMatrixWidget(tires: viewModel.tires)
                    FluidTempsWidget(engine: viewModel.engine)
                }
                .frame(width: 220)

                // Center Stage: Speedometer & Gearing
                VStack(spacing: 10) {
                    SpeedometerWidget(motion: viewModel.motion)
                    LapTimingWidget(timing: viewModel.timing)
                }
                .frame(maxWidth: .infinity)

                // Right Wing: Pedals & Telemetry Diagnostics
                VStack(spacing: 10) {
                    PedalClusterWidget(inputs: viewModel.inputs)
                    
                    if let carCode = viewModel.carCode {
                        MetricCard(
                            label: "CAR ID",
                            valueText: "\(carCode)",
                            unitText: nil
                        )
                    }
                }
                .frame(width: 180)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Header Bar (Portrait)

    private var headerBar: some View {
        HStack(spacing: 10) {
            // Live Status Indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(viewModel.isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)

                Text(viewModel.isConnected ? "LIVE (60HZ)" : "DISCONNECTED")
                    .font(TelemetryTypography.label)
                    .foregroundColor(viewModel.isConnected ? Color.green : TelemetryColors.mutedText)
            }

            if let carCode = viewModel.carCode {
                Text("• #\(carCode)")
                    .font(TelemetryTypography.unit)
                    .foregroundColor(TelemetryColors.mutedText)
            }

            Spacer()

            // Header Controls
            HStack(spacing: 8) {
                autoRecordToggle
                manualRecordButton

                Button(action: { viewModel.disconnect() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(TelemetryColors.mutedText)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Control Components

    private var autoRecordToggle: some View {
        Button(action: {
            viewModel.isAutoRecordingEnabled.toggle()
        }) {
            HStack(spacing: 4) {
                Image(systemName: viewModel.isAutoRecordingEnabled ? "bolt.fill" : "bolt.slash")
                    .font(.caption2)
                Text("AUTO")
                    .font(TelemetryTypography.label)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(viewModel.isAutoRecordingEnabled ? Color.green.opacity(0.15) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(viewModel.isAutoRecordingEnabled ? Color.green.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 1)
            )
            .foregroundColor(viewModel.isAutoRecordingEnabled ? Color.green : TelemetryColors.mutedText)
        }
    }

    private var manualRecordButton: some View {
        Button(action: {
            viewModel.toggleManualRecording()
        }) {
            HStack(spacing: 5) {
                Circle()
                    .fill(viewModel.isRecording ? Color.red : Color.secondary.opacity(0.4))
                    .frame(width: 6, height: 6)
                Text(viewModel.isRecording ? "REC" : "LOG")
                    .font(TelemetryTypography.label)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(viewModel.isRecording ? Color.red.opacity(0.15) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(viewModel.isRecording ? Color.red.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 1)
            )
            .foregroundColor(viewModel.isRecording ? Color.red : TelemetryColors.mutedText)
        }
    }

    // MARK: - Recording Status Banner

    private var recordingStatusBanner: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(viewModel.isRecordingPaused ? Color.yellow : Color.red)
                .frame(width: 7, height: 7)

            Text(viewModel.isRecordingPaused ? "SESSION PAUSED" : "RECORDING TELEMETRY (60HZ)")
                .font(TelemetryTypography.unit)
                .foregroundColor(viewModel.isRecordingPaused ? Color.yellow : Color.red)

            Spacer()

            if let url = viewModel.lastSavedFileURL {
                Text(url.lastPathComponent)
                    .font(TelemetryTypography.unit)
                    .foregroundColor(TelemetryColors.mutedText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(viewModel.isRecordingPaused ? Color.yellow.opacity(0.08) : Color.red.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(viewModel.isRecordingPaused ? Color.yellow.opacity(0.25) : Color.red.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - Previews

#Preview("Dashboard - Portrait Recording") {
    let vm = TelemetryViewModel()
    vm.isConnected = true
    vm.isRecording = true
    vm.isAutoRecordingEnabled = true
    vm.motion = .racing
    vm.engine = .racing
    vm.inputs = .trailBraking
    vm.tires = .optimal
    vm.timing = .racing
    return DashboardView(viewModel: vm)
}

#Preview("Dashboard - Landscape Cockpit", traits: .landscapeLeft) {
    let vm = TelemetryViewModel()
    vm.isConnected = true
    vm.isRecording = true
    vm.isAutoRecordingEnabled = true
    vm.motion = .racing
    vm.engine = .shiftAlert
    vm.inputs = .fullThrottle
    vm.tires = .optimal
    vm.timing = .racing
    return DashboardView(viewModel: vm)
}