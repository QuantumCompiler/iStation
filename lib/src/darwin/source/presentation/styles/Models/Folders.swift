// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

/// Folders as the design writes them: from "~" under the person's home folder ("~/Documents/Console"),
/// as the BIOS pane, Game info and the scan job name the folder a file is kept in. Pure: the home folder
/// is given, since the App Store build's sandbox reports its container as home.
public enum Folders {
    /// `folder` from "~" when it is `home` or inside it; as it is otherwise, or when `home` is unknown.
    public static func shown(_ folder: String, home: String?) -> String {
        guard var home, !home.isEmpty else { return folder }
        while home.count > 1 && home.hasSuffix("/") { home.removeLast() }
        if folder == home { return "~" }
        guard folder.hasPrefix(home + "/") else { return folder }
        return "~" + folder.dropFirst(home.count)
    }
}
