// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import Foundation

/// SYSTEM.CNF from the root of a PS1 or PS2 disc.
///
/// PS2 discs boot with `BOOT2 = cdrom0:\SLUS_200.62;1`, PS1 discs with `BOOT = cdrom:\SLUS_005.94;1`.
/// That one key is the reliable way to tell the two consoles apart, since both use the same serial prefixes.
public struct SystemCNF: Equatable, Sendable {
    /// The console a boot key belongs to.
    public enum Console: String, Sendable {
        case ps1, ps2
    }

    public let console: Console
    public let serial: String?

    public init?(text: String) {
        var boot: String?
        var boot2: String?
        for line in text.components(separatedBy: .newlines) {
            let parts = line.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces).uppercased()
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            if key == "BOOT2" { boot2 = value }
            if key == "BOOT" { boot = value }
        }

        if let boot2 {
            console = .ps2
            serial = Self.serial(fromBootPath: boot2)
        } else if let boot {
            console = .ps1
            serial = Self.serial(fromBootPath: boot)
        } else {
            return nil
        }
    }

    /// `cdrom0:\SLUS_200.62;1` → `SLUS-20062`. Returns nil for non-standard executables (e.g. `PSX.EXE`).
    static func serial(fromBootPath path: String) -> String? {
        var name = path
        if let separator = name.lastIndex(where: { $0 == "\\" || $0 == "/" || $0 == ":" }) {
            name = String(name[name.index(after: separator)...])
        }
        if let semicolon = name.firstIndex(of: ";") { name = String(name[..<semicolon]) }
        let normalized = name.uppercased()
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "_", with: "-")
        return normalized.range(of: #"^[A-Z]{4}-\d{5}$"#, options: .regularExpression) != nil ? normalized : nil
    }
}
