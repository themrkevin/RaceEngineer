import SwiftUI
import TelemetryKit

struct DashboardView: View {
    @Bindable var viewModel: TelemetryViewModel
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header: Status & Connection
                HStack {
                    Circle()
                        .fill(viewModel.isConnected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(viewModel.isConnected ? "LIVE TELEMETRY" : "DISCONNECTED")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                    Spacer()
                    
                    // Oil/Water Temps
                    HStack(spacing: 15) {
                        TempReadout(label: "OIL", value: viewModel.oilTemp)
                        TempReadout(label: "H2O", value: viewModel.waterTemp)
                    }
                }
                .padding(.horizontal)
                
                // RPM Section
                VStack(spacing: 8) {
                    HStack {
                        Text("RPM")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(Int(viewModel.engineRPM))")
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal)
                    
                    RPMGaugeView(rpm: viewModel.engineRPM)
                        .frame(height: 40)
                }
                
                // Main Stats Row
                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        Text("CAR")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                        Text("\(viewModel.carCode ?? 0)")
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)

                    // Gear
                    VStack(spacing: 0) {
                        Text("GEAR")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                        Text(viewModel.gear == 0 ? "N" : "\(viewModel.gear)")
                            .font(.system(size: 60, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                }

                HStack(spacing: 0) {   
                    // Speed
                    VStack(spacing: 0) {
                        Text("SPEED")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                        Text("\(Int(viewModel.speedMph))")
                            .font(.system(size: 100, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        Text("MPH")
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                }

                HStack(spacing: 0) {
                    // Lap Info
                    VStack(spacing: 0) {
                        Text("LAP")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                        Text("\(viewModel.currentLapNumber)")
                            .font(.system(size: 60, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                }
                
                Spacer()
                
                // Bottom Telemetry Grid
                HStack(alignment: .bottom, spacing: 20) {
                    // Tires
                    VStack(spacing: 10) {
                        Text("TIRES")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                        TireGrid(tireData: viewModel.tireTemps)
                    }
                    
                    Spacer()
                    
                    // Inputs (Including Clutch)
                    VStack(spacing: 10) {
                        Text("INPUTS")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                        InputPedalsView(throttle: viewModel.throttle, brake: viewModel.brake, clutch: viewModel.clutch)
                    }
                    
                    Spacer()
                    
                    // Fuel
                    VStack(spacing: 10) {
                        Text("FUEL")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                        FuelGaugeView(level: viewModel.fuelLevel, capacity: viewModel.fuelCapacity)
                    }
                }
                .padding(.bottom, 30)
            }
            .padding(.horizontal)
            
            // Disconnect Button
            VStack {
                HStack {
                    Spacer()
                    Button(action: { viewModel.disconnect() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white.opacity(0.2))
                    }
                    .padding()
                }
                Spacer()
            }
        }
    }
}

struct TempReadout: View {
    let label: String
    let value: Float
    var body: some View {
        HStack(spacing: 4) {
            Text(label).font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
            Text("\(Int(value))°").font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(.white)
        }
    }
}

// MARK: - Subviews

struct RPMGaugeView: View {
    let rpm: Float
    let maxRPM: Float = 8000 // In a real app, this would come from the packet
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                
                Rectangle()
                    .fill(rpmColor(for: rpm))
                    .frame(width: geo.size.width * CGFloat(min(rpm / maxRPM, 1.0)))
            }
            .cornerRadius(4)
        }
    }
    
    private func rpmColor(for rpm: Float) -> Color {
        let percent = rpm / maxRPM
        if percent > 0.95 { return .blue } // Shift light
        if percent > 0.85 { return .red }
        if percent > 0.70 { return .yellow }
        return .green
    }
}

struct TireGrid: View {
    let tireData: TireData<Float>
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                TireView(temp: tireData.frontLeft)
                TireView(temp: tireData.frontRight)
            }
            HStack(spacing: 4) {
                TireView(temp: tireData.rearLeft)
                TireView(temp: tireData.rearRight)
            }
        }
    }
}

struct TireView: View {
    let temp: Float
    
    var body: some View {
        Rectangle()
            .fill(tempColor(for: temp))
            .frame(width: 40, height: 60)
            .cornerRadius(4)
            .overlay(
                Text("\(Int(temp))°")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            )
    }
    
    private func tempColor(for temp: Float) -> Color {
        if temp < 70 { return .blue.opacity(0.8) }
        if temp < 95 { return .green.opacity(0.8) }
        return .red.opacity(0.8)
    }
}

struct InputPedalsView: View {
    let throttle: Float
    let brake: Float
    let clutch: Float
    
    var body: some View {
        HStack(spacing: 12) {
            // Clutch
            PedalBar(value: clutch, color: .blue, label: "C")
            // Brake
            PedalBar(value: brake, color: .red, label: "B")
            // Throttle
            PedalBar(value: throttle, color: .green, label: "T")
        }
    }
}

struct PedalBar: View {
    let value: Float
    let color: Color
    let label: String
    
    var body: some View {
        VStack {
            ZStack(alignment: .bottom) {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 10, height: 80)
                Rectangle()
                    .fill(color)
                    .frame(width: 10, height: 80 * CGFloat(min(max(value, 0), 1)))
            }
            Text(label).font(.system(size: 8, design: .monospaced)).foregroundColor(.gray)
        }
    }
}

struct FuelGaugeView: View {
    let level: Float
    let capacity: Float
    
    var body: some View {
        VStack {
            Text("FUEL")
                .font(.caption2)
                .foregroundColor(.gray)
            ZStack(alignment: .bottom) {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 30, height: 80)
                Rectangle()
                    .fill(level / capacity < 0.15 ? Color.red : Color.white)
                    .frame(width: 30, height: 80 * CGFloat(max(0, min(level / (capacity > 0 ? capacity : 100), 1))))
            }
            .cornerRadius(2)
        }
    }
}
