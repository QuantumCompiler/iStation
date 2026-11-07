// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

/// The PS1 console the apps play.
///
/// Today a powered-off placeholder: the R3000A (v0.0.1 item 3e) and the memory map and devices
/// around it (3f) fill it in. It imports nothing but the standard library, as every core does
/// (ADR 0015).
public final class PS1Console {
    /// The console's name, as the player shows it.
    public static let name = "PlayStation"

    /// False until the console has a CPU and a BIOS to run.
    public private(set) var isPoweredOn = false

    public init() {}
}
