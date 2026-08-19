import Foundation

/// Defines static byte offsets for the Gran Turismo 7 UDP Packet C (368-byte / 396-byte) telemetry packet.
/// All multi-byte numeric values are encoded in little-endian byte order.
public enum GT7PacketMapping {
    
    // MARK: - 1. Packet Validation & Spatial Kinematics (0x00 - 0x3B)
    public enum Kinematics {
        public static let magic = 0x00                 // UInt32 — 0x47375330 ("0S7G")
        public static let positionX = 0x04             // Float32 (meters)
        public static let positionY = 0x08             // Float32 (meters)
        public static let positionZ = 0x0C             // Float32 (meters)
        public static let velocityX = 0x10             // Float32 (m/s)
        public static let velocityY = 0x14             // Float32 (m/s)
        public static let velocityZ = 0x18             // Float32 (m/s)
        public static let pitch = 0x1C                 // Float32 (radians)
        public static let yaw = 0x20                   // Float32 (radians)
        public static let roll = 0x24                  // Float32 (radians)
        public static let angularVelocityX = 0x2C      // Float32 (rad/s)
        public static let angularVelocityY = 0x30      // Float32 (rad/s)
        public static let angularVelocityZ = 0x34      // Float32 (rad/s)
        public static let bodyHeight = 0x38            // Float32 (meters)
    }

    // MARK: - 2. Powertrain, Fluids & Speed (0x3C - 0x5F)
    public enum Powertrain {
        public static let engineRPM = 0x3C             // Float32 (RPM)
        public static let fuelCapacity = 0x44          // Float32 (liters)
        public static let fuelLevel = 0x48             // Float32 (liters)
        public static let carSpeed = 0x4C              // Float32 (m/s)
        public static let turboBoost = 0x50            // Float32 (bar / kPa offset)
        public static let oilPressure = 0x54           // Float32 (bar)
        public static let waterTemp = 0x58             // Float32 (°C)
        public static let oilTemp = 0x5C               // Float32 (°C)
    }

    // MARK: - 3. Tire Surface Temperatures (0x60 - 0x6F)
    public enum Tires {
        public static let tempFrontLeft = 0x60         // Float32 (°C)
        public static let tempFrontRight = 0x64        // Float32 (°C)
        public static let tempRearLeft = 0x68          // Float32 (°C)
        public static let tempRearRight = 0x6C         // Float32 (°C)
    }

    // MARK: - 4. Sequence & Session Timing (0x70 - 0x8F)
    public enum Session {
        public static let packetSequence = 0x70        // Int32 (monotonically increasing counter)
        public static let currentLap = 0x74            // Int16 (1-indexed, -1 on grid/uninitialized)
        public static let totalLaps = 0x76             // Int16 (0 in free run / time trial)
        public static let bestLapTime = 0x78           // Int32 (milliseconds, -1 sentinel)
        public static let lastLapTime = 0x7C           // Int32 (milliseconds, -1 sentinel)
        public static let timeOfDayProgression = 0x80  // Int32 (milliseconds)
        public static let racePosition = 0x8C          // Int16 (position on track)
        public static let sessionFlags = 0x8E          // UInt16 (candidate session-state bitmask)
    }

    // MARK: - 5. Driver Inputs & Transmission (0x90 - 0x93)
    public enum Inputs {
        public static let gear = 0x90                  // UInt8 (low nibble & 0x0F = active gear, high nibble >> 4 = suggested)
        public static let throttle = 0x91              // UInt8 (0...255 -> 0.0...1.0)
        public static let brake = 0x92                 // UInt8 (0...255 -> 0.0...1.0)
        public static let roadSurfaceFlags = 0x93      // UInt8
    }

    // MARK: - 6. Suspension & Wheel Dynamics (0xA4 - 0xD3)
    public enum Suspension {
        public static let wheelAngularVelocityFL = 0xA4 // Float32 (rad/s)
        public static let wheelAngularVelocityFR = 0xA8 // Float32 (rad/s)
        public static let wheelAngularVelocityRL = 0xAC // Float32 (rad/s)
        public static let wheelAngularVelocityRR = 0xB0 // Float32 (rad/s)
        public static let tireRadiusFL = 0xB4          // Float32 (meters)
        public static let tireRadiusFR = 0xB8          // Float32 (meters)
        public static let tireRadiusRL = 0xBC          // Float32 (meters)
        public static let tireRadiusRR = 0xC0          // Float32 (meters)
        public static let suspensionTravelFL = 0xC4    // Float32 (meters)
        public static let suspensionTravelFR = 0xC8    // Float32 (meters)
        public static let suspensionTravelRL = 0xCC    // Float32 (meters)
        public static let suspensionTravelRR = 0xD0    // Float32 (meters)
    }

    // MARK: - 7. Extended Packet C Channels (0xD4 - 0x16F)
    public enum Extended {
        public static let carCode = 0x124              // Int32 (unique car identifier, -1 when uninitialized)
        public static let wheelSteeringAngleFL = 0x12C // Float32 (radians)
        public static let wheelSteeringAngleFR = 0x130 // Float32 (radians)
        public static let wheelbase = 0x134            // Float32 (meters)
        public static let surfaceTypeFL = 0x158        // UInt8 (ASCII 'T', 'C', 'D')
        public static let surfaceTypeFR = 0x159        // UInt8 (ASCII 'T', 'C', 'D')
        public static let surfaceTypeRL = 0x15A        // UInt8 (ASCII 'T', 'C', 'D')
        public static let surfaceTypeRR = 0x15B        // UInt8 (ASCII 'T', 'C', 'D')
    }
}
