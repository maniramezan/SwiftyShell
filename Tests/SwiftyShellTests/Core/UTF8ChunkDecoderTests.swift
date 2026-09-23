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
}
