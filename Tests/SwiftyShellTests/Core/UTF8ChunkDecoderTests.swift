import Foundation
import Testing
@testable import SwiftyShell

struct UTF8ChunkDecoderTests {
    private static let sample = "a€b😀c é"

    @Test(arguments: 0...Array(sample.utf8).count)
    func splittingAtAnyByteOffsetPreservesText(offset: Int) {
        let bytes = Array(Self.sample.utf8)
        var decoder = UTF8ChunkDecoder()

        var text = decoder.decode(Data(bytes[..<offset])) ?? ""
        text += decoder.decode(Data(bytes[offset...])) ?? ""
        text += decoder.finish() ?? ""

        #expect(text == Self.sample)
    }

    @Test func decodesSlicedDataWithNonZeroStartIndex() {
        let backing = Data([0x78, 0x78] + Array("a€".utf8))
        let slice = backing[2...]
        var decoder = UTF8ChunkDecoder()

        #expect(decoder.decode(slice.dropLast()) == "a")
        #expect(decoder.decode(Data([0xAC])) == "€")
    }

    @Test func singleByteChunksPreserveText() {
        var decoder = UTF8ChunkDecoder()
        var text = ""
        for byte in Self.sample.utf8 {
            text += decoder.decode(Data([byte])) ?? ""
        }
        text += decoder.finish() ?? ""

        #expect(text == Self.sample)
    }

    @Test func holdsBackIncompleteSequence() {
        var decoder = UTF8ChunkDecoder()

        #expect(decoder.decode(Data([0xE2, 0x82])) == nil)
        #expect(decoder.decode(Data([0xAC])) == "€")
        #expect(decoder.finish() == nil)
    }

    @Test func finishReplacesTruncatedSequence() {
        var decoder = UTF8ChunkDecoder()

        #expect(decoder.decode(Data([0x61, 0xE2, 0x82])) == "a")
        #expect(decoder.finish() == "\u{FFFD}")
    }

    @Test func invalidBytesAreNotHeldBack() {
        var decoder = UTF8ChunkDecoder()

        #expect(decoder.decode(Data([0x61, 0xFF])) == "a\u{FFFD}")
        #expect(decoder.finish() == nil)
    }

    @Test(
        arguments: [
            [0xC0], [0xC1], [0xF5], [0xF7], [0x80], [0xBF],
            [0xE0, 0x80], [0xED, 0xA0], [0xF0, 0x80], [0xF4, 0x90],
            [0xF0, 0x80, 0x80], [0xF4, 0x90, 0x80],
        ] as [[UInt8]]
    )
    func invalidPrefixesDecodeImmediately(bytes: [UInt8]) {
        var decoder = UTF8ChunkDecoder()

        #expect(decoder.decode(Data(bytes)) == String(decoding: bytes, as: UTF8.self))
        #expect(decoder.finish() == nil)
    }

    @Test(
        arguments: [
            [0xC2, 0x80], [0xDF, 0xBF], [0xE0, 0xA0, 0x80], [0xED, 0x9F, 0xBF],
            [0xF0, 0x90, 0x80, 0x80], [0xF4, 0x8F, 0xBF, 0xBF],
        ] as [[UInt8]]
    )
    func boundaryScalarsRemainPendingUntilComplete(bytes: [UInt8]) {
        var decoder = UTF8ChunkDecoder()

        for byte in bytes.dropLast() {
            #expect(decoder.decode(Data([byte])) == nil)
        }
        #expect(decoder.decode(Data([bytes.last!])) == String(decoding: bytes, as: UTF8.self))
        #expect(decoder.finish() == nil)
    }

    @Test func emptyChunksPreservePendingBytes() {
        var decoder = UTF8ChunkDecoder()

        #expect(decoder.decode(Data()) == nil)
        #expect(decoder.decode(Data([0xE2])) == nil)
        #expect(decoder.decode(Data()) == nil)
        #expect(decoder.decode(Data([0x82, 0xAC])) == "€")
        #expect(decoder.finish() == nil)
    }

}
