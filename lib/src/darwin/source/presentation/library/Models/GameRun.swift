// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

/// What a PS-EXE's opening job powered the player's session on with, as the library hands it to whatever
/// shows the run once the program starts — the app passes it to the player as its run, as it does the BIOS
/// pane's `BIOSRun`, so this module knows nothing of the player: the BIOS file's name where it is kept now
/// and how many bytes the session was powered on with, and the program's name and file. The bytes
/// themselves stay with the session.
public struct GameRun: Sendable, Equatable {
    /// The BIOS file's name: "my-console-bios.bin".
    public var biosFileName: String
    /// How many bytes of BIOS the session was powered on with: 524,288.
    public var biosSize: Int
    /// The program's name as the library shows it: "gpu-test".
    public var name: String
    /// The program's file name: "gpu-test.exe".
    public var fileName: String

    /// A run of the program `name`, read from `fileName`, over the BIOS in `biosFileName`, `biosSize` bytes.
    public init(biosFileName: String, biosSize: Int, name: String, fileName: String) {
        self.biosFileName = biosFileName
        self.biosSize = biosSize
        self.name = name
        self.fileName = fileName
    }
}
