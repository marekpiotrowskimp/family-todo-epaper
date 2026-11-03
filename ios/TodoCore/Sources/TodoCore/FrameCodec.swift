import Foundation

/// Ramki BLE, identyczne jak w `todo/frame.h`: [seq: UInt16 LE][flags: UInt8, bit0 = ostatnia][payload].
public enum FrameCodec {
    public static let headerBytes = 3
    public static let lastFlag: UInt8 = 0x01
    public static let maxMessageBytes = 16 * 1024

    /// Ramki o rozmiarze <= `maxFrameBytes` (z nagłówkiem). Pusta wiadomość to jedna ramka z samym nagłówkiem.
    public static func split(_ message: Data, maxFrameBytes: Int) -> [Data] {
        guard maxFrameBytes > headerBytes else { return [] }
        let bytes = [UInt8](message)
        let chunk = maxFrameBytes - headerBytes
        var frames: [Data] = []
        var position = 0
        var seq: UInt16 = 0
        repeat {
            let end = min(position + chunk, bytes.count)
            let flags: UInt8 = end == bytes.count ? lastFlag : 0
            frames.append(Data([UInt8(seq & 0xFF), UInt8(seq >> 8), flags] + bytes[position..<end]))
            position = end
            seq &+= 1
        } while position < bytes.count
        return frames
    }
}

public enum FrameResult: Equatable {
    case incomplete
    case complete(Data)
    case error
}

public struct FrameReassembler {
    private var buffer: [UInt8] = []
    private var lastSeq: Int?

    public init() {}

    /// Te same reguły co `todo::Reassembler::feed`.
    public mutating func feed(_ frame: Data) -> FrameResult {
        let bytes = [UInt8](frame)
        guard bytes.count >= FrameCodec.headerBytes else { return fail() }
        let seq = Int(bytes[0]) | Int(bytes[1]) << 8
        if let lastSeq {
            if seq == lastSeq { return .incomplete }  // retransmisja
            guard seq == lastSeq + 1 else { return fail() }
        } else {
            guard seq == 0 else { return fail() }
        }
        let payload = bytes[FrameCodec.headerBytes...]
        guard buffer.count + payload.count <= FrameCodec.maxMessageBytes else { return fail() }
        buffer += payload
        lastSeq = seq
        guard bytes[2] & FrameCodec.lastFlag != 0 else { return .incomplete }
        let message = Data(buffer)
        reset()
        return .complete(message)
    }

    public mutating func reset() {
        buffer = []
        lastSeq = nil
    }

    private mutating func fail() -> FrameResult {
        reset()
        return .error
    }
}
