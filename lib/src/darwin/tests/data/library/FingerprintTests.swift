// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import DataLibrary
import Foundation
import Testing

/// The SHA-1 fingerprint against digests worked out independently (FIPS 180's "abc" and empty-message
/// examples, and `shasum -a 1` over 524,288 zero bytes): 40 lowercase digits, leading zeros kept.
@Suite struct FingerprintTests {
    @Test func abcHasTheStandardsDigest() {
        #expect(Fingerprint.sha1(of: Array("abc".utf8)) == "a9993e364706816aba3e25717850c26c9cd0d89d")
    }

    @Test func nothingHasTheEmptyMessagesDigest() {
        #expect(Fingerprint.sha1(of: [UInt8]()) == "da39a3ee5e6b4b0d3255bfef95601890afd80709")
    }

    @Test func a512KBImageOfZerosHasItsDigest() {
        let image = [UInt8](repeating: 0, count: 524_288)
        #expect(Fingerprint.sha1(of: image) == "6a521e1d2a632c26e53b83d2cc4b0edecfc1e68c")
        #expect(Fingerprint.sha1(of: Data(image)) == Fingerprint.sha1(of: image)) // bytes or Data, the same
    }

    @Test func theDigestIsFortyLowercaseHexDigitsWithItsLeadingZeros() {
        let digest = Fingerprint.sha1(of: Array("abc".utf8))
        #expect(digest.count == 40)
        #expect(digest.allSatisfy { "0123456789abcdef".contains($0) })
        #expect(digest.contains("4706")) // the byte 0x06 keeps its leading zero
    }
}
