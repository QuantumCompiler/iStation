// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import Foundation

/// Why a kept file couldn't be bookmarked, found again or read, with the system's own reason for Details.
public enum KeptFileError: Error, Equatable, Sendable {
    /// No bookmark could be made to the file at `path`.
    case cannotBookmark(path: String, reason: String)
    /// The bookmark no longer leads to a file: it was deleted, its volume is gone, or the bookmark is damaged.
    case cannotResolve(reason: String)
    /// The file at `path` couldn't be read.
    case cannotRead(path: String, reason: String)
}

/// A file the user chose, kept where the user keeps it — by a bookmark, never copied: the BIOS (5c), and
/// from 5d the games. It makes the bookmark the library stores, finds the file again from it, and reads
/// the file's bytes, each inside the file's security-scoped access, so the same calls serve a URL the
/// file picker just gave and one a bookmark gave back after a relaunch.
///
/// On macOS the bookmark is security-scoped (`.withSecurityScope`), which keeps a sandboxed app's
/// access across launches. The App Store sandbox may refuse to make one without the
/// `com.apple.security.files.bookmarks.app-scope` entitlement, which stays off until the bookmark probe
/// (`tools/bookmark-probe/`) shows it is needed (contract row C11): when it refuses, a plain bookmark is
/// made instead, which still finds the file but may not open it after a relaunch. On iOS a plain
/// bookmark carries the picked file's access itself.
public enum KeptFile {
    /// Where a bookmark leads now.
    public struct Resolved: Sendable, Equatable {
        /// The file's URL, security-scoped where the bookmark was.
        public var url: URL
        /// True when the system says the bookmark should be made again — the file moved or was renamed —
        /// and the new one stored in place of the old (`bookmark(for:)` on `url`).
        public var isStale: Bool

        /// A resolution of these values.
        public init(url: URL, isStale: Bool) {
            self.url = url
            self.isStale = isStale
        }
    }

    /// A bookmark to the file at `url`, for the library to store: security-scoped on macOS, or plain when
    /// the sandbox refuses that (see the type's note).
    public static func bookmark(for url: URL) throws(KeptFileError) -> Data {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            #if os(macOS)
            do {
                return try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            } catch {
                return try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            }
            #else
            return try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            #endif
        } catch {
            throw .cannotBookmark(path: url.path, reason: error.localizedDescription)
        }
    }

    /// Where `bookmark` leads now, and whether it is stale. Resolving shows no UI and mounts nothing.
    public static func resolve(_ bookmark: Data) throws(KeptFileError) -> Resolved {
        var isStale = false
        do {
            #if os(macOS)
            let url: URL
            do {
                url = try URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope, .withoutUI, .withoutMounting],
                              relativeTo: nil, bookmarkDataIsStale: &isStale)
            } catch {
                // A plain bookmark, made where the sandbox refused a security-scoped one: resolving it
                // with the security scope fails as a wrong format, so it is resolved plainly.
                url = try URL(resolvingBookmarkData: bookmark, options: [.withoutUI, .withoutMounting],
                              relativeTo: nil, bookmarkDataIsStale: &isStale)
            }
            #else
            let url = try URL(resolvingBookmarkData: bookmark, options: [.withoutUI, .withoutMounting],
                              relativeTo: nil, bookmarkDataIsStale: &isStale)
            #endif
            return Resolved(url: url, isStale: isStale)
        } catch {
            throw .cannotResolve(reason: error.localizedDescription)
        }
    }

    /// The size in bytes of the file at `url`, read inside its security-scoped access without reading
    /// the file: a caller that refuses a file of the wrong size — a disc image picked by mistake —
    /// needn't read gigabytes to say so. A symbolic link is sized as the file it leads to, the one
    /// `bytes(at:)` reads, never as the link itself.
    public static func size(at url: URL) throws(KeptFileError) -> Int {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.resolvingSymlinksInPath().path)
            guard let size = (attributes[.size] as? NSNumber)?.intValue else {
                throw CocoaError(.fileReadUnknown)
            }
            return size
        } catch {
            throw .cannotRead(path: url.path, reason: error.localizedDescription)
        }
    }

    /// The bytes of the file at `url`, read inside its security-scoped access. The whole file is read:
    /// a caller that refuses files above a size checks `size(at:)` first.
    public static func bytes(at url: URL) throws(KeptFileError) -> [UInt8] {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            return [UInt8](try Data(contentsOf: url))
        } catch {
            throw .cannotRead(path: url.path, reason: error.localizedDescription)
        }
    }
}
