// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

/// What a run of the console plays, as whatever started it tells the player — the BIOS check (5c) or
/// the library's opening job (5d): the BIOS file the console was powered on with and, for a PS-EXE, the
/// program booted after it. The player names it in the HUD and the Stop alert, and Reset's Details
/// name its files; the bytes stay with the session.
public struct PlayerRun: Sendable, Equatable {
    /// A PS-EXE given to `boot(exe:)` right after power-on.
    public struct Program: Sendable, Equatable {
        /// The program's name as the library shows it: "gpu-test".
        public var name: String
        /// Its file's name: "gpu-test.exe".
        public var fileName: String

        /// A program named `name`, read from the file `fileName`.
        public init(name: String, fileName: String) {
            self.name = name
            self.fileName = fileName
        }
    }

    /// The BIOS file's own name, as the person kept it: "my-console-bios.bin".
    public var biosFileName: String
    /// The BIOS file's size in bytes.
    public var biosSize: Int
    /// The PS-EXE booted after power-on; nil while the BIOS runs alone.
    public var program: Program?

    /// A run of the BIOS in `biosFileName`, `biosSize` bytes, booting `program` if one is given.
    public init(biosFileName: String, biosSize: Int, program: Program? = nil) {
        self.biosFileName = biosFileName
        self.biosSize = biosSize
        self.program = program
    }
}
