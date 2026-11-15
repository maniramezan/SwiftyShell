import Foundation
import Testing

@testable import SwiftyShell

struct ChunkListTests {
    @Test func dropsFromFrontAcrossManyOneByteChunks() {
        var list = ChunkList()
        let capacity = 4096
        var expected = Data()
        for index in 0..<50_000 {
            let byte = UInt8(truncatingIfNeeded: index)
            let chunk = Data([byte])
            list.dropFirstBytes(max(0, list.byteCount + chunk.count - capacity))
            list.append(chunk)
            expected.append(byte)
            if expected.count > capacity {
                expected.removeFirst(expected.count - capacity)
            }
        }
        #expect(list.byteCount == capacity)
        #expect(list.joined() == expected)
    }

    @Test func dropTrimsPartiallyConsumedChunk() {
        var list = ChunkList()
        list.append(Data("abcd".utf8))
        list.append(Data("efgh".utf8))
        list.dropFirstBytes(6)
        #expect(list.byteCount == 2)
        #expect(list.joined() == Data("gh".utf8))
    }

    @Test func dropMoreThanStoredEmptiesList() {
        var list = ChunkList()
        list.append(Data("abc".utf8))
        list.dropFirstBytes(10)
        #expect(list.byteCount == 0)
        #expect(list.joined().isEmpty)
    }

    @Test func ignoresEmptyAppendsAndReplacesAll() {
        var list = ChunkList()
        list.append(Data())
        #expect(list.byteCount == 0)
        list.append(Data("abc".utf8))
        list.replaceAll(with: Data("xy".utf8))
        #expect(list.byteCount == 2)
        #expect(list.joined() == Data("xy".utf8))
        list.removeAll()
        #expect(list.byteCount == 0)
    }

    @Test func compactionKeepsContentOrderAfterHeadAdvances() {
        var list = ChunkList()
        for index in 0..<300 {
            list.append(Data([UInt8(index % 251)]))
        }
        list.dropFirstBytes(200)
        list.append(Data([7]))
        let expected = Data((200..<300).map { UInt8($0 % 251) } + [7])
        #expect(list.joined() == expected)
        #expect(list.byteCount == 101)
    }
}
