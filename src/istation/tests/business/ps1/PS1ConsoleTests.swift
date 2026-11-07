// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import BusinessPS1
import Testing

@Suite struct PS1ConsoleTests {
    @Test func aNewConsoleIsPoweredOff() {
        #expect(!PS1Console().isPoweredOn)
        #expect(PS1Console.name == "PlayStation")
    }
}
