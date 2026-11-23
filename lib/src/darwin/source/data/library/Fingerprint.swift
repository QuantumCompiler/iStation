// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import CryptoKit
import Foundation

/// A file's fingerprint, as the app names a kept BIOS: its SHA-1 digest, worked out by CryptoKit when the
/// file is recorded. SHA-1 is a name for the file here, not a protection: the BIOS pane shows it in groups
/// of four, as the design does, while the gate's reports keep naming a BIOS by its size and SHA-256.
public enum Fingerprint {
    /// The SHA-1 digest of `bytes`, as 40 lowercase hexadecimal digits: "abc" gives
    /// "a9993e364706816aba3e25717850c26c9cd0d89d".
    public static func sha1(of bytes: some DataProtocol) -> String {
        Insecure.SHA1.hash(data: bytes).map { byte in
            let digits = String(byte, radix: 16)
            return digits.count == 1 ? "0" + digits : digits
        }.joined()
    }
}
