// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import Foundation

/// .cue sheets and .m3u multi-disc playlists both point at other files on disk.
public enum Playlists {
    /// Every `FILE "..."` referenced by a cue sheet, resolved relative to the cue's folder.
    public static func cueTracks(_ cue: URL) -> [URL] {
        guard let text = (try? String(contentsOf: cue, encoding: .utf8))
            ?? (try? String(contentsOf: cue, encoding: .isoLatin1))
        else { return [] }
        let folder = cue.deletingLastPathComponent()
        return text.components(separatedBy: .newlines).compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.uppercased().hasPrefix("FILE ") else { return nil }
            let name: String
            if let open = trimmed.firstIndex(of: "\""),
               let close = trimmed[trimmed.index(after: open)...].firstIndex(of: "\"") {
                name = String(trimmed[trimmed.index(after: open)..<close])
            } else {
                // Unquoted form: FILE name.bin BINARY
                let parts = trimmed.split(separator: " ")
                guard parts.count >= 2 else { return nil }
                name = String(parts[1])
            }
            return folder.appendingPathComponent(name)
        }
    }

    /// Disc entries of an .m3u playlist, skipping comments.
    public static func m3uEntries(_ playlist: URL) -> [URL] {
        guard let text = try? String(contentsOf: playlist, encoding: .utf8) else { return [] }
        let folder = playlist.deletingLastPathComponent()
        return text.components(separatedBy: .newlines).compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return nil }
            return trimmed.hasPrefix("/") ? URL(fileURLWithPath: trimmed) : folder.appendingPathComponent(trimmed)
        }
    }
}
