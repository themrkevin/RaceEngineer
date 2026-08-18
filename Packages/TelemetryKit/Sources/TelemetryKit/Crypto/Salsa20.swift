import Foundation

/// A high-performance, zero-allocation native Swift implementation of the Salsa20 stream cipher.
/// Optimized for 60Hz real-time GT7 telemetry processing.
public enum Salsa20 {
    
    // MARK: - Pre-computed Constants (Little-Endian UInt32)
    
    // "expand 32-byte k" constants
    private static let c0: UInt32 = 0x61707865 // "expa"
    private static let c1: UInt32 = 0x3320646e // "nd 3"
    private static let c2: UInt32 = 0x79622d32 // "2-by"
    private static let c3: UInt32 = 0x6b206574 // "te k"
    
    // "Simulator Interface Packet GT7 ver 0.0" (first 32 bytes)
    private static let k0: UInt32 = 0x756d6953 // "Simu"
    private static let k1: UInt32 = 0x6f74616c // "lato"
    private static let k2: UInt32 = 0x6e492072 // "r In"
    private static let k3: UInt32 = 0x66726574 // "terf"
    private static let k4: UInt32 = 0x20656361 // "ace "
    private static let k5: UInt32 = 0x6b636150 // "Pack"
    private static let k6: UInt32 = 0x47207465 // "et G"
    private static let k7: UInt32 = 0x76203754 // "T7 v"

    /// Decrypts the GT7 payload in-place with zero heap allocations.
    /// - Parameter data: The raw 396-byte encrypted packet received from the console.
    /// - Returns: A decrypted `Data` buffer containing the telemetry payload.
    public static func decrypt(data: Data) -> Data {
        // Guard against malformed/short UDP packets (need at least 0x44 to read IV)
        guard data.count >= 0x44 else { return data }
        
        // 1. Extract IVs from packet offset 0x40
        let iv1 = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 0x40, as: UInt32.self) }
        let iv2 = iv1 ^ 0xDEADBEEF
        
        var decrypted = data
        let packetSize = decrypted.count
        let numBlocks = (packetSize + 63) / 64
        
        decrypted.withUnsafeMutableBytes { (rawBuffer: UnsafeMutableRawBufferPointer) in
            guard let bytes = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            
            // Stack-allocated 64-byte keystream buffer
            var keyStream = (
                UInt64(0), UInt64(0), UInt64(0), UInt64(0),
                UInt64(0), UInt64(0), UInt64(0), UInt64(0)
            )
            
            withUnsafeMutableBytes(of: &keyStream) { streamBuf in
                guard let streamPtr = streamBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
                
                for blockIndex in 0..<numBlocks {
                    // Generate 64-byte keystream block on stack
                    salsa20Block(
                        iv1: iv1,
                        iv2: iv2,
                        blockIndex: UInt32(blockIndex),
                        output: streamPtr
                    )
                    
                    let start = blockIndex * 64
                    let end = min(start + 64, packetSize)
                    let blockSize = end - start
                    
                    // XOR in-place
                    for j in 0..<blockSize {
                        bytes[start + j] ^= streamPtr[j]
                    }
                }
            }
        }
        
        return decrypted
    }
    
    // MARK: - Core Salsa20 20-Round Transform
    
    @inline(__always)
    private static func salsa20Block(
        iv1: UInt32,
        iv2: UInt32,
        blockIndex: UInt32,
        output: UnsafeMutablePointer<UInt8>
    ) {
        // Initial state matrix (16 x 32-bit words)
        var x0 = c0;  var x1 = k0;  var x2 = k1;  var x3 = k2
        var x4 = k3;  var x5 = c1;  var x6 = iv2; var x7 = iv1
        var x8 = blockIndex; var x9: UInt32 = 0; var x10 = c2; var x11 = k4
        var x12 = k5; var x13 = k6; var x14 = k7; var x15 = c3
        
        let in0 = x0;   let in1 = x1;   let in2 = x2;   let in3 = x3
        let in4 = x4;   let in5 = x5;   let in6 = x6;   let in7 = x7
        let in8 = x8;   let in9 = x9;   let in10 = x10; let in11 = x11
        let in12 = x12; let in13 = x13; let in14 = x14; let in15 = x15
        
        // 20 rounds (10 iterations of double-round)
        for _ in 0..<10 {
            // Column rounds
            x4 ^= rotl(x0 &+ x12, 7);   x8 ^= rotl(x4 &+ x0, 9)
            x12 ^= rotl(x8 &+ x4, 13);  x0 ^= rotl(x12 &+ x8, 18)
            x9 ^= rotl(x5 &+ x1, 7);    x13 ^= rotl(x9 &+ x5, 9)
            x1 ^= rotl(x13 &+ x9, 13);  x5 ^= rotl(x1 &+ x13, 18)
            x14 ^= rotl(x10 &+ x6, 7);  x2 ^= rotl(x14 &+ x10, 9)
            x6 ^= rotl(x2 &+ x14, 13);  x10 ^= rotl(x6 &+ x2, 18)
            x3 ^= rotl(x15 &+ x11, 7);  x7 ^= rotl(x3 &+ x15, 9)
            x11 ^= rotl(x7 &+ x3, 13);  x15 ^= rotl(x11 &+ x7, 18)
            
            // Row rounds
            x1 ^= rotl(x0 &+ x3, 7);    x2 ^= rotl(x1 &+ x0, 9)
            x3 ^= rotl(x2 &+ x1, 13);   x0 ^= rotl(x3 &+ x2, 18)
            x6 ^= rotl(x5 &+ x4, 7);    x7 ^= rotl(x6 &+ x5, 9)
            x4 ^= rotl(x7 &+ x6, 13);   x5 ^= rotl(x4 &+ x7, 18)
            x11 ^= rotl(x10 &+ x9, 7);  x8 ^= rotl(x11 &+ x10, 9)
            x9 ^= rotl(x8 &+ x11, 13);  x10 ^= rotl(x9 &+ x8, 18)
            x12 ^= rotl(x15 &+ x14, 7); x13 ^= rotl(x12 &+ x15, 9)
            x14 ^= rotl(x13 &+ x12, 13);x15 ^= rotl(x14 &+ x13, 18)
        }
        
        // Write out 16 UInt32 words directly into output pointer (little-endian)
        let outWords = output.withMemoryRebound(to: UInt32.self, capacity: 16) { $0 }
        outWords[0]  = (x0  &+ in0).littleEndian
        outWords[1]  = (x1  &+ in1).littleEndian
        outWords[2]  = (x2  &+ in2).littleEndian
        outWords[3]  = (x3  &+ in3).littleEndian
        outWords[4]  = (x4  &+ in4).littleEndian
        outWords[5]  = (x5  &+ in5).littleEndian
        outWords[6]  = (x6  &+ in6).littleEndian
        outWords[7]  = (x7  &+ in7).littleEndian
        outWords[8]  = (x8  &+ in8).littleEndian
        outWords[9]  = (x9  &+ in9).littleEndian
        outWords[10] = (x10 &+ in10).littleEndian
        outWords[11] = (x11 &+ in11).littleEndian
        outWords[12] = (x12 &+ in12).littleEndian
        outWords[13] = (x13 &+ in13).littleEndian
        outWords[14] = (x14 &+ in14).littleEndian
        outWords[15] = (x15 &+ in15).littleEndian
    }
    
    @inline(__always)
    private static func rotl(_ value: UInt32, _ count: Int) -> UInt32 {
        (value << count) | (value >> (32 - count))
    }
}