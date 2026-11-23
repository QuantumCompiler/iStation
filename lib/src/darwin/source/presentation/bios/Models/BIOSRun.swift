// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

/// What Run the BIOS powered the player's session on with, as the BIOS pane hands it to whatever shows
/// the run — the app passes it to the player as its run: the file's name where it is kept now, and how
/// many bytes the session was powered on with. The bytes themselves stay with the session.
public struct BIOSRun: Sendable, Equatable {
    /// The BIOS file's name: "my-console-bios.bin".
    public var fileName: String
    /// How many bytes the session was powered on with: 524,288.
    public var size: Int

    /// A run of the BIOS in `fileName`, `size` bytes.
    public init(fileName: String, size: Int) {
        self.fileName = fileName
        self.size = size
    }
}
