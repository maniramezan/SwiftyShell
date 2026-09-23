import Foundation

/// Decodes a byte stream into UTF-8 text chunk by chunk without splitting multi-byte scalars.
///
/// Pipe reads return arbitrary byte counts, so a scalar such as `€` (three bytes) can straddle two
/// reads. Decoding each read on its own would turn both halves into U+FFFD. This decoder holds back
/// an incomplete trailing sequence and prepends it to the next chunk.
struct UTF8ChunkDecoder {
    private var pending: [UInt8] = []

    /// Decodes `data` plus any bytes held back from the previous call.
    ///
    /// - Returns: The decoded text, or `nil` when every byte is still pending.
    mutating func decode(_ data: Data) -> String? {
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
    /// Only the last three bytes are inspected: a UTF-8 sequence is at most four bytes long, so an
    /// incomplete one can hold back at most three. Invalid bytes are not held back; they decode to
    /// U+FFFD as usual.
    static func completeLength(of bytes: [UInt8]) -> Int {
        let count = bytes.count
        var index = count - 1
        while index >= 0, index >= count - 3 {
            let byte = bytes[index]
            if byte & 0b1100_0000 != 0b1000_0000 {
                // Found a lead (or ASCII / invalid) byte; check whether its sequence is complete.
                let expectedLength: Int
                switch byte {
                case 0b1100_0000...0b1101_1111: expectedLength = 2
                case 0b1110_0000...0b1110_1111: expectedLength = 3
                case 0b1111_0000...0b1111_0111: expectedLength = 4
                default: return count
                }
                return count - index < expectedLength ? index : count
            }
            index -= 1
        }
        return count
    }
}
