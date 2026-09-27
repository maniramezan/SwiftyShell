import Foundation

/// Decodes a byte stream into UTF-8 text chunk by chunk without splitting multi-byte scalars.
///
/// Pipe reads return arbitrary byte counts, so a scalar such as `€` (three bytes) can straddle two
/// reads. Decoding each read on its own would turn both halves into U+FFFD. This decoder holds back
/// an incomplete trailing sequence and prepends it to the next chunk.
struct UTF8ChunkDecoder {
    // UTF-8 continuation bytes have the bit pattern `10xxxxxx`; the mask selects those two prefix bits.
    private static let continuationByteMask: UInt8 = 0xC0
    private static let continuationBytePrefix: UInt8 = 0x80
    private static let maximumIncompleteSequenceLength = 4

    private var pending: [UInt8] = []

    /// Decodes `data` plus any bytes held back from the previous call.
    ///
    /// - Returns: The decoded text, or `nil` when every byte is still pending.
    mutating func decode(_ data: Data) -> String? {
        guard !pending.isEmpty else {
            // Common case: nothing held back, so decode straight from `data` without copying it.
            let boundary = data.index(data.startIndex, offsetBy: Self.completeLength(of: data))
            pending = Array(data[boundary...])
            guard boundary > data.startIndex else { return nil }
            return String(decoding: data[..<boundary], as: UTF8.self)
        }
        var bytes = pending
        bytes.append(contentsOf: data)
        let boundary = Self.completeLength(of: bytes)
        pending = Array(bytes[boundary...])
        guard boundary > 0 else { return nil }
        return String(decoding: bytes[..<boundary], as: UTF8.self)
    }

    /// Decodes any held-back bytes, replacing an incomplete trailing sequence with U+FFFD.
    ///
    /// - Returns: The remaining text, or `nil` when nothing is pending.
    mutating func finish() -> String? {
        guard !pending.isEmpty else { return nil }
        defer { pending.removeAll() }
        return String(decoding: pending, as: UTF8.self)
    }

    /// Returns the length of the longest prefix of `bytes` that does not end inside an incomplete
    /// multi-byte sequence.
    ///
    /// Only the final three bytes need inspection: a UTF-8 scalar uses at most four bytes, so its
    /// lead byte can be followed by at most three bytes that have arrived so far. Invalid bytes
    /// are not held back; they decode to U+FFFD as usual.
    static func completeLength<Bytes: BidirectionalCollection<UInt8>>(of bytes: Bytes) -> Int {
        let count = bytes.count
        var index = bytes.endIndex
        var trailingByteCount = 0
        while index > bytes.startIndex, trailingByteCount < maximumIncompleteSequenceLength - 1 {
            index = bytes.index(before: index)
            trailingByteCount += 1
            let byte = bytes[index]
            if byte & continuationByteMask != continuationBytePrefix {
                // This is a lead byte, ASCII byte, or invalid byte. Only lead bytes need a length check.
                let sequenceLength: Int
                switch byte {
                // `110xxxxx` starts a 2-byte scalar (U+0080...U+07FF).
                case 0xC0...0xDF: sequenceLength = 2
                // `1110xxxx` starts a 3-byte scalar (U+0800...U+FFFF).
                case 0xE0...0xEF: sequenceLength = 3
                // `11110xxx` starts a 4-byte scalar (U+10000...U+10FFFF).
                case 0xF0...0xF7: sequenceLength = 4
                default: return count
                }
                // `trailingByteCount` includes this lead byte, so fewer bytes than the sequence needs
                // means the sequence is incomplete and must be carried into the next read.
                return trailingByteCount < sequenceLength ? count - trailingByteCount : count
            }
        }
        return count
    }
}
