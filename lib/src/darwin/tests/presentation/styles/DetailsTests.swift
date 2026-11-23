// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import PresentationStyles
import Testing

/// Details name the exact call that failed and what it threw, as the design writes them.
@Suite struct DetailsTests {
    enum SampleError: Error {
        case biosSize(Int)
        case gone
    }

    struct DiskFull: Error, CustomStringConvertible {
        var description: String { "the disk is full" }
    }

    @Test func anEnumsCaseIsNamedWithItsType() {
        #expect(Details.threw("PS1Console.powerOn(bios:)", SampleError.biosSize(1_000)) == "PS1Console.powerOn(bios:) threw SampleError.biosSize(1000)")
        #expect(Details.threw("KeptFile.resolve(_:)", SampleError.gone) == "KeptFile.resolve(_:) threw SampleError.gone")
    }

    @Test func anyOtherErrorDescribesItself() {
        #expect(Details.threw("KeptFile.bytes(at:)", DiskFull()) == "KeptFile.bytes(at:) threw the disk is full")
    }
}
