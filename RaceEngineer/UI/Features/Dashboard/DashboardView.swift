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
            }
        }
    }

    // MARK: - Portrait Layout

    private var portraitLayout: some View {
        VStack(spacing: 16) {
            // Header Bar
            headerBar

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
            // Full-Width RPM Bar on Top
            HStack(spacing: 12) {
                RPMGaugeWidget(engine: viewModel.engine)
                
                // Disconnect Button
                Button(action: { viewModel.disconnect() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(TelemetryColors.mutedText)
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

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(viewModel.isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)

                Text(viewModel.isConnected ? "LIVE TELEMETRY (60HZ)" : "DISCONNECTED")
                    .font(TelemetryTypography.label)
                    .foregroundColor(viewModel.isConnected ? Color.green : TelemetryColors.mutedText)
            }

            if let carCode = viewModel.carCode {
                Text("• CAR #\(carCode)")
                    .font(TelemetryTypography.unit)
                    .foregroundColor(TelemetryColors.mutedText)
            }

            Spacer()

            Button(action: { viewModel.disconnect() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(TelemetryColors.mutedText)
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Previews

#Preview("Dashboard - Portrait Racing") {
    let vm = TelemetryViewModel()
    vm.isConnected = true
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
    vm.motion = .racing
    vm.engine = .shiftAlert
    vm.inputs = .fullThrottle
    vm.tires = .optimal
    vm.timing = .racing
    return DashboardView(viewModel: vm)
}
