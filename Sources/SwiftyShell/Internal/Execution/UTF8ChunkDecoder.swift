import Foundation

/// Decodes a byte stream into UTF-8 text chunk by chunk without splitting multi-byte scalars.
///
/// Pipe reads return arbitrary byte counts, so a scalar such as `€` (three bytes) can straddle two
/// reads. Decoding each read on its own would turn both halves into U+FFFD. This decoder holds back
/// an incomplete trailing sequence and prepends it to the next chunk.
struct UTF8ChunkDecoder {
    private static let continuationBytes: ClosedRange<UInt8> = 0x80...0xBF
    private static let maximumUTF8ScalarLength = 4

    private var pending: [UInt8] = []

    /// Decodes `data` plus any bytes held back from the previous call.
    ///
    /// - Returns: The decoded text, or `nil` when every byte is still pending.
    mutating func decode(_ data: Data) -> String? {
        guard !pending.isEmpty else {
            // Common case: nothing held back, so decode straight from `data` without copying it.
            let boundary = Self.completePrefixEnd(in: data)
            pending = Array(data[boundary...])
            guard boundary > data.startIndex else { return nil }
            return String(decoding: data[..<boundary], as: UTF8.self)
        }
        var bytes = pending
        bytes.append(contentsOf: data)
        let boundary = Self.completePrefixEnd(in: bytes)
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

    /// Returns the end of the prefix that can be decoded without splitting a UTF-8 scalar.
    ///
    /// A valid incomplete scalar occupies at most three trailing bytes. Invalid prefixes are
    /// returned for immediate decoding with replacement characters by `String(decoding:as:)`.
    private static func completePrefixEnd<Bytes: BidirectionalCollection<UInt8>>(
        in bytes: Bytes
    ) -> Bytes.Index {
        let candidateIndices = bytes.indices.reversed().prefix(maximumUTF8ScalarLength - 1)
        for (offset, index) in candidateIndices.enumerated() {
            let leadByte = bytes[index]
            guard !continuationBytes.contains(leadByte) else { continue }

            let scalarLength: Int
            switch leadByte {
            case 0xC2...0xDF: scalarLength = 2
            case 0xE0...0xEF: scalarLength = 3
            case 0xF0...0xF4: scalarLength = maximumUTF8ScalarLength
            default: return bytes.endIndex
            }

            let availableByteCount = offset + 1
            guard availableByteCount < scalarLength else { return bytes.endIndex }
            guard availableByteCount > 1 else { return index }

            // These lead bytes restrict the second byte to exclude overlong encodings,
            // UTF-16 surrogates, and values above U+10FFFF. Later continuation bytes need
            // no additional checks: the backward scan has already checked their range.
            let secondByte = bytes[bytes.index(after: index)]
            let validSecondBytes: ClosedRange<UInt8>
            switch leadByte {
            case 0xE0: validSecondBytes = 0xA0...0xBF
            case 0xED: validSecondBytes = 0x80...0x9F
            case 0xF0: validSecondBytes = 0x90...0xBF
            case 0xF4: validSecondBytes = 0x80...0x8F
            default: validSecondBytes = continuationBytes
            }
            return validSecondBytes.contains(secondByte) ? index : bytes.endIndex
        }
        return bytes.endIndex
    }
}
