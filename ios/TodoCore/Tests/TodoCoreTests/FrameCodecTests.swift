import Foundation
import Testing
@testable import TodoCore

/// Te same przypadki co test/test_frame w firmware.
@Suite struct FrameCodecTests {
    func message(_ n: Int) -> Data {
        Data((0..<n).map { UInt8(ascii: "a") + UInt8($0 % 26) })
    }

    func split(_ m: Data, _ max: Int, atLeast n: Int) throws -> [Data] {
        let frames = FrameCodec.split(m, maxFrameBytes: max)
        try #require(frames.count >= n)
        return frames
    }

    @Test func splitRespectsMaxFrameSizeAndNumbersFrames() throws {
        let f = try split(message(50), 20, atLeast: 3)
        #expect(f.map(\.count) == [20, 20, 19])
        #expect(f.map { Array($0.prefix(3)) } == [[0, 0, 0], [1, 0, 0], [2, 0, FrameCodec.lastFlag]])
        #expect(f[1][f[1].startIndex + 3] == UInt8(ascii: "r"))
    }

    @Test func emptyMessageIsSingleHeaderFrame() {
        #expect(FrameCodec.split(Data(), maxFrameBytes: 20) == [Data([0, 0, FrameCodec.lastFlag])])
    }

    @Test func reassemblesFramesInOrder() throws {
        let m = message(300)
        let f = try split(m, 23, atLeast: 2)
        var r = FrameReassembler()
        for frame in f.dropLast() { #expect(r.feed(frame) == .incomplete) }
        #expect(r.feed(f[f.count - 1]) == .complete(m))
    }

    @Test func retransmittedFrameIsIgnored() throws {
        let m = message(40)
        let f = try split(m, 20, atLeast: 3)
        var r = FrameReassembler()
        _ = r.feed(f[0])
        #expect(r.feed(f[0]) == .incomplete)
        _ = r.feed(f[1])
        #expect(r.feed(f[2]) == .complete(m))
    }

    @Test func gapIsErrorAndResets() throws {
        let m = message(40)
        let f = try split(m, 20, atLeast: 3)
        var r = FrameReassembler()
        _ = r.feed(f[0])
        #expect(r.feed(f[2]) == .error)
        _ = r.feed(f[0])
        _ = r.feed(f[1])
        #expect(r.feed(f[2]) == .complete(m))
    }

    @Test func messageMustStartAtSeqZero() throws {
        let f = try split(message(40), 20, atLeast: 2)
        var r = FrameReassembler()
        #expect(r.feed(f[1]) == .error)
    }

    @Test func frameShorterThanHeaderIsError() {
        var r = FrameReassembler()
        #expect(r.feed(Data([0, 0])) == .error)
    }

    @Test func messageOverLimitIsError() throws {
        let f = try split(message(FrameCodec.maxMessageBytes + 1), 512, atLeast: 2)
        var r = FrameReassembler()
        var last = FrameResult.incomplete
        for frame in f {
            last = r.feed(frame)
            if last != .incomplete { break }
        }
        #expect(last == .error)
    }
}
