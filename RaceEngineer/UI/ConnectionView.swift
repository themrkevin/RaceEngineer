import SwiftUI

@MainActor
struct ConnectionView: View {
    @State private var viewModel: TelemetryViewModel
    @State private var ipAddress: String = UserDefaults.standard.string(forKey: "PS5_IP") ?? "192.168.1."
    
    init() {
        _viewModel = State(initialValue: TelemetryViewModel())
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if viewModel.isConnected {
                    DashboardView(viewModel: viewModel)
                        .transition(.opacity)
                } else {
                    VStack(spacing: 30) {
                        Image(systemName: "steeringwheel")
                            .font(.system(size: 80))
                            .foregroundColor(.white)
                            .padding(.bottom, 20)
                        
                        Text("RaceEngineer")
                            .font(.largeTitle.bold())
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text("PS5 IP Address")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            TextField("192.168.1.XX", text: $ipAddress)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(10)
                                .foregroundColor(.white)
                                .keyboardType(.decimalPad)
                                .onChange(of: ipAddress) { _, newValue in
                                    UserDefaults.standard.set(newValue, forKey: "PS5_IP")
                                }
                        }
                        .padding(.horizontal, 40)
                        
                        Button(action: { viewModel.connect(ipAddress: ipAddress) }) {
                            Text("Connect to GT7")
                                .font(.headline)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal, 40)
                        
                        Button(action: { viewModel.connect(ipAddress: "0.0.0.0", isMock: true) }) {
                            Text("Simulation Mode")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        
                        if let error = viewModel.connectionError {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    ConnectionView()
        .preferredColorScheme(.dark)
}
