// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import DataTracing
import Testing

/// FNV-1a 64's published test vectors, and the register checksum's order, computed independently.
@Suite struct ChecksumTests {
    @Test func fnv1a64MatchesItsPublishedVectors() {
        func of(_ text: String) -> UInt64 {
            var checksum = FNV1a64()
            checksum.add(bytes: Array(text.utf8))
            return checksum.value
        }
        #expect(of("") == 0xCBF2_9CE4_8422_2325)
        #expect(of("a") == 0xAF63_DC4C_8601_EC8C)
        #expect(of("foobar") == 0x8594_4171_F739_67E8)
    }

    @Test func theRegisterChecksumCoversThirtySevenWordsInOrder() {
        #expect(RegisterChecksum.of(gpr: Array(repeating: 0, count: 32), hi: 0, lo: 0, sr: 0, cause: 0, epc: 0) == 0x63DF_F573_DC19_F335)
        #expect(RegisterChecksum.of(gpr: Array(0..<32), hi: 0xAAAA_5555, lo: 0x1234_5678, sr: 0x1000_0000, cause: 0x20, epc: 0xBFC0_0180)
            == 0x96DB_4701_0582_CEA9)
    }

    @Test func aFullStateCarriesTheSameChecksumAsAnInstructionRecord() {
        let state = FullStateRecord(cycles: 0, pc: 0, gpr: Array(0..<32), hi: 0xAAAA_5555, lo: 0x1234_5678, sr: 0x1000_0000, cause: 0x20, epc: 0xBFC0_0180)
        #expect(state.registerChecksum == 0x96DB_4701_0582_CEA9)
    }
}
