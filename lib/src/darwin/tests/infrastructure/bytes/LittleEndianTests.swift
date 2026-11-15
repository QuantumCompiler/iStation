// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import InfrastructureBytes
import Testing

@Suite struct LittleEndianTests {
    @Test func readsLittleEndianIntegers() {
        let bytes: [UInt8] = [0x34, 0x12, 0x78, 0x56]
        #expect(bytes.u16le(0) == 0x1234)
        #expect(bytes.u16le(2) == 0x5678)
        #expect(bytes.u32le(0) == 0x5678_1234)
    }

    @Test func readsPastEitherEndAreZero() {
        let bytes: [UInt8] = [0x01, 0x02, 0x03]
        #expect(bytes.u16le(2) == 0)
        #expect(bytes.u32le(0) == 0)
        #expect(bytes.u16le(-1) == 0)
    }
}
