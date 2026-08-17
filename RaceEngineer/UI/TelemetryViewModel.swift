import SwiftUI
import Observation
import TelemetryKit

@Observable
@MainActor
class TelemetryViewModel {
    // Current State
    var carCode: Int32? = nil
    var speedKmh: Float = 0
    var speedMph: Float = 0
    var engineRPM: Float = 0
    var gear: Int = 0
    var throttle: Float = 0
    var brake: Float = 0
    var clutch: Float = 0
    var tireTemps = TireData<Float>(frontLeft: 0, frontRight: 0, rearLeft: 0, rearRight: 0)
    var oilTemp: Float = 0
    var waterTemp: Float = 0
    var fuelLevel: Float = 0
    var fuelCapacity: Float = 0
    var currentLapNumber: Int = 0
    
    var isConnected = false
    var connectionError: String?
    
    private var provider: (any TelemetryProvider)?
    private var streamTask: Task<Void, Never>?
    
    func connect(ipAddress: String, isMock: Bool = false) {
        isConnected = false
        connectionError = nil
        
        provider = isMock ? MockTelemetryProvider() : GT7TelemetryProvider()
        
        Task {
            do {
                try await provider?.start(ipAddress: ipAddress)
                isConnected = true
                
                // Start listening to the stream
                streamTask?.cancel()
                streamTask = Task { [weak self] in
                    guard let provider = self?.provider else { return }
                    let stream = provider.telemetryStream()
                    
                    for await packet in stream {
                        if Task.isCancelled { break }
                        self?.update(with: packet)
                    }
                }
            } catch {
                connectionError = "Failed to connect: \(error.localizedDescription)"
                isConnected = false
            }
        }
    }
    
    func disconnect() {
        Task {
            await provider?.stop()
            streamTask?.cancel()
            streamTask = nil
            isConnected = false
        }
    }
    
    private func update(with packet: TelemetryPacket) {
        // We are on @MainActor, so we can update UI state directly
        self.carCode = packet.carCode
        self.speedKmh = packet.speedKmh
        self.speedMph = packet.speedMph
        self.engineRPM = packet.engineRPM
        self.gear = packet.gear
        self.throttle = packet.throttle
        self.brake = packet.brake
        self.clutch = packet.clutchPedal
        self.tireTemps = packet.tireSurfaceTemps
        self.oilTemp = packet.oilTemp
        self.waterTemp = packet.waterTemp
        self.fuelLevel = packet.fuelLevel
        self.fuelCapacity = packet.fuelCapacity
        self.currentLapNumber = packet.currentLapNumber
    }
}
