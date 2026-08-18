import SwiftUI

@MainActor
public struct ConnectionView: View {
    @State private var viewModel: TelemetryViewModel
    @State private var ipAddress: String = UserDefaults.standard.string(forKey: "PS5_IP") ?? "192.168.1."

    public init(viewModel: TelemetryViewModel? = nil) {
        _viewModel = State(initialValue: viewModel ?? TelemetryViewModel())
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                TelemetryColors.background
                    .ignoresSafeArea()

                if viewModel.isConnected {
                    DashboardView(viewModel: viewModel)
                        .transition(.opacity)
                } else {
                    connectionForm
                }
            }
        }
    }

    // MARK: - Connection Form

    private var connectionForm: some View {
        VStack(spacing: 28) {
            Spacer()

            // App Brand Header
            VStack(spacing: 12) {
                Image(systemName: "steeringwheel")
                    .font(.system(size: 72))
                    .foregroundColor(TelemetryColors.brightText)

                Text("RaceEngineer")
                    .font(.largeTitle.bold())
                    .foregroundColor(TelemetryColors.brightText)

                Text("Real-Time GT7 Telemetry & Engineering HUD")
                    .font(TelemetryTypography.unit)
                    .foregroundColor(TelemetryColors.mutedText)
            }

            // IP Configuration Card
            VStack(alignment: .leading, spacing: 10) {
                Text("PLAYSTATION 5 IP ADDRESS")
                    .font(TelemetryTypography.label)
                    .foregroundColor(TelemetryColors.mutedText)

                TextField("192.168.1.XX", text: $ipAddress)
                    .textFieldStyle(.plain)
                    .font(TelemetryTypography.secondaryValue)
                    .padding()
                    .background(TelemetryColors.surfaceSecondary)
                    .cornerRadius(10)
                    .foregroundColor(TelemetryColors.brightText)
                    .keyboardType(.decimalPad)
                    .telemetryMonospacedDigits()
                    .onChange(of: ipAddress) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "PS5_IP")
                    }

                Text("UDP Ports: Inbound 33740 | Heartbeat 33739")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(TelemetryColors.mutedText.opacity(0.8))
            }
            .padding(.horizontal, 36)

            // Primary Connect Button
            VStack(spacing: 14) {
                Button(action: { viewModel.connect(ipAddress: ipAddress) }) {
                    HStack(spacing: 8) {
                        if viewModel.isConnecting {
                            ProgressView()
                                .tint(Color.black)
                        }
                        Text(viewModel.isConnecting ? "Connecting to GT7..." : "Connect to PS5")
                            .font(.headline)
                            .foregroundColor(.black)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
                }
                .disabled(viewModel.isConnecting)

                // Simulation Mode
                Button(action: { viewModel.connect(ipAddress: "0.0.0.0", isMock: true) }) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.circle.fill")
                        Text("Launch Simulation (Mock 60Hz Stream)")
                    }
                    .font(.subheadline)
                    .foregroundColor(TelemetryColors.mutedText)
                }
                .disabled(viewModel.isConnecting)
            }
            .padding(.horizontal, 36)

            // Error Message Banner
            if let error = viewModel.connectionError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(TelemetryTypography.unit)
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 36)
            }

            Spacer()
        }
    }
}

#Preview("Connection Screen") {
    ConnectionView()
        .preferredColorScheme(.dark)
}

