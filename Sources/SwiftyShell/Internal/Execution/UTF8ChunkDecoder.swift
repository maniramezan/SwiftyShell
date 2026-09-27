import Foundation

/// Decodes a byte stream into UTF-8 text chunk by chunk without splitting multi-byte scalars.
///
/// Pipe reads return arbitrary byte counts, so a scalar such as `€` (three bytes) can straddle two
/// reads. Decoding each read on its own would turn both halves into U+FFFD. This decoder holds back
/// an incomplete trailing sequence and prepends it to the next chunk.
struct UTF8ChunkDecoder {
    // UTF-8 lead-byte ranges for valid scalars. C0/C1 would encode ASCII using too many
    // bytes; F5...FF would exceed Unicode's maximum scalar value (U+10FFFF).
    private static let twoByteScalarLeads: ClosedRange<UInt8> = 0xC2...0xDF
    private static let threeByteScalarLeads: ClosedRange<UInt8> = 0xE0...0xEF
    private static let fourByteScalarLeads: ClosedRange<UInt8> = 0xF0...0xF4
    private static let continuationBytes: ClosedRange<UInt8> = 0x80...0xBF
    private static let maximumUTF8ScalarLength = 4

    // Special second-byte limits at the edges of the three- and four-byte encodings.
    private static let secondBytesAvoidingOverlongThreeByteEncoding: ClosedRange<UInt8> = 0xA0...0xBF
    private static let secondBytesAvoidingOverlongFourByteEncoding: ClosedRange<UInt8> = 0x90...0xBF
    private static let secondBytesWithinUnicodeLimit: ClosedRange<UInt8> = 0x80...0x8F
    private static let surrogateRangeLead: UInt8 = 0xED
    private static let secondBytesExcludingSurrogates: ClosedRange<UInt8> = 0x80...0x9F

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
            case twoByteScalarLeads: scalarLength = 2
            case threeByteScalarLeads: scalarLength = 3
            case fourByteScalarLeads: scalarLength = maximumUTF8ScalarLength
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
            case threeByteScalarLeads.lowerBound: validSecondBytes = secondBytesAvoidingOverlongThreeByteEncoding
            case surrogateRangeLead: validSecondBytes = secondBytesExcludingSurrogates
            case fourByteScalarLeads.lowerBound: validSecondBytes = secondBytesAvoidingOverlongFourByteEncoding
            case fourByteScalarLeads.upperBound: validSecondBytes = secondBytesWithinUnicodeLimit
            default: validSecondBytes = continuationBytes
            }
            return validSecondBytes.contains(secondByte) ? index : bytes.endIndex
        }
        return bytes.endIndex
    }
}
