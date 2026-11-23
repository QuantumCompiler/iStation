// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import PresentationStyles
import Testing

/// Numbers as the design writes them, the same in every module that shows one: the player's frame
/// count, the BIOS check's sizes and its error's byte count.
@Suite struct FiguresTests {
    @Test func numbersAreGroupedByThousandsAsTheDesignWritesThem() {
        #expect(Figures.grouped(0) == "0")
        #expect(Figures.grouped(999) == "999")
        #expect(Figures.grouped(1_000) == "1,000")
        #expect(Figures.grouped(271_384) == "271,384")
        #expect(Figures.grouped(524_288) == "524,288")
        #expect(Figures.grouped(1_048_576) == "1,048,576")
        #expect(Figures.grouped(-12_345) == "-12,345")
    }
}
