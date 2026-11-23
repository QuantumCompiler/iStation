// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import DataPlaylists
import Foundation

/// The games in the files a person chose: the ones a folder holds (Add Folder…'s search) and the record
/// the library keeps of each (Add Games…, Add Folder… and Locate…). A game is a .cue, .iso, .m3u or
/// .exe file; the files a .cue names as its tracks and an .m3u lists as its discs come with it, read by
/// `Playlists`, and are never games of their own. Nothing is copied: a game is kept by its bookmark.
///
/// Each call reads inside the security-scoped access of the URL it is given. A search's files are
/// reached through the folder's access, so a caller that records them after the search keeps the
/// folder's access open until the last is recorded (`startAccessingSecurityScopedResource()` on the
/// folder the file chooser gave).
public enum GameFiles {
    /// The largest .cue or .m3u read for the files it names, 1 MiB: a cue sheet or playlist is a few
    /// lines, so a bigger file of that name is something else, and isn't read whole.
    public static let playlistLimit = 1 << 20

    /// The games in `folder` and its subfolders, in path order: every .cue, .iso, .m3u and .exe file,
    /// whatever the case of its extension, except a file a .cue among them names as a track, or an .m3u
    /// lists as a disc — with that disc's own tracks — since those come with it: one entry for an .m3u
    /// and its discs, and none for a .cue's .bin tracks (`withoutParts(_:)`). Hidden files and the insides
    /// of packages are passed over, and so is a subfolder that can't be read. A task cancelled mid-search
    /// ends it early, with the games found so far. Throws `cannotRead` when `folder` isn't a folder that
    /// can be read.
    public static func find(in folder: URL) throws(KeptFileError) -> [URL] {
        let accessing = folder.startAccessingSecurityScopedResource()
        defer { if accessing { folder.stopAccessingSecurityScopedResource() } }
        let isFolder: Bool
        do {
            isFolder = try folder.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
        } catch {
            throw .cannotRead(path: folder.path, reason: error.localizedDescription)
        }
        guard isFolder else { throw .cannotRead(path: folder.path, reason: "It isn’t a folder.") }
        guard let enumerator = FileManager.default.enumerator(
            at: folder, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else {
            throw .cannotRead(path: folder.path, reason: "Its files couldn’t be listed.")
        }
        var games: [URL] = []
        while let next = enumerator.nextObject() {
            if Task.isCancelled { break }
            // A symbolic link isn't a regular file, so a link to a game is passed over, as a linked folder is.
            guard let url = next as? URL, GameFormat(fileName: url.lastPathComponent) != nil,
                  (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true
            else { continue }
            games.append(url)
        }
        return withoutParts(games.sorted { $0.path.compare($1.path, options: [.caseInsensitive, .numeric]) == .orderedAscending })
    }

    /// `games`, in their order, less each one that comes with another: a .cue's track, an .m3u's disc and
    /// that disc's own tracks, told apart by the file itself, not by how the sheet or playlist spells it —
    /// on a volume that ignores case, a playlist's "tidepool (disc 1).cue" is "Tidepool (Disc 1).cue", and
    /// a symbolic link it names is the file it leads to — except that of games that are one file by hard
    /// links, the part is the one it names (`games(named:paths:index:)`). A game nothing lists stays, and
    /// so does a playlist that lists itself; what a game that stays lists goes, and what that lists in
    /// turn. Playlists that list each other and nothing else lists keep one of them, the first in path
    /// order, so no game of theirs disappears, and what they list goes with them — another ring among it too.
    static func withoutParts(_ games: [URL]) -> [URL] {
        var index: [FileKey: [Int]] = [:]
        for (game, file) in games.map(FileKey.init).enumerated() { index[file, default: []].append(game) }
        // Each game that shares its file with another, by its path with symbolic links resolved, worked
        // out once: a part names one of them by that path.
        var shared: [Int: String] = [:]
        for sharing in index.values where sharing.count > 1 {
            for game in sharing { shared[game] = games[game].resolvingSymlinksInPath().path }
        }
        let parts: [[Int]] = games.indices.map { game in
            Self.parts(of: games[game]).flatMap { Self.games(named: $0, paths: shared, index: index) }.filter { $0 != game }
        }
        var kept = Set<Int>()
        var gone = Set<Int>()
        func keep(_ game: Int) {
            kept.insert(game)
            var listed = parts[game]
            while let part = listed.popLast() {
                guard !kept.contains(part), gone.insert(part).inserted else { continue }
                listed += parts[part]
            }
        }
        let listed = Set(parts.joined())
        for game in games.indices where !listed.contains(game) { keep(game) }
        // What is left is listed only from among itself: playlists in rings, and what the rings list. Each
        // ring nothing else left lists is headed by its first game in path order (the order `games` comes
        // in), which takes the rest of the ring with it and what the ring lists — so a ring another lists,
        // or a playlist a ring lists, is never a head. Keeping one head never reaches another.
        let left = games.indices.filter { !kept.contains($0) && !gone.contains($0) }
        for head in Self.ringHeads(of: left, parts: parts) { keep(head) }
        return games.indices.filter(kept.contains).map { games[$0] }
    }

    /// The first, by index, of each ring among `games` that nothing among them outside the ring lists: the
    /// least game of each source component of the graph `parts` draws over `games` alone — its strongly
    /// connected components found once, by Tarjan's walk, without recursion, so a long chain of playlists
    /// can't overflow the stack. In index order.
    static func ringHeads(of games: [Int], parts: [[Int]]) -> [Int] {
        let among = Set(games)
        var found: [Int: Int] = [:]
        var low: [Int: Int] = [:]
        var stack: [Int] = []
        var onStack = Set<Int>()
        var component: [Int: Int] = [:]
        var components = 0
        func visit(_ game: Int) {
            found[game] = found.count
            low[game] = found[game]
            stack.append(game)
            onStack.insert(game)
        }
        for root in games where found[root] == nil {
            visit(root)
            var walk: [(game: Int, next: Int)] = [(root, 0)]
            while let top = walk.last {
                let listed = parts[top.game]
                if top.next < listed.count {
                    walk[walk.count - 1].next += 1
                    let part = listed[top.next]
                    guard among.contains(part) else { continue }
                    if found[part] == nil {
                        visit(part)
                        walk.append((part, 0))
                    } else if onStack.contains(part), let reached = found[part], let own = low[top.game] {
                        low[top.game] = min(own, reached)
                    }
                    continue
                }
                walk.removeLast()
                if let parent = walk.last?.game, let own = low[parent], let child = low[top.game] {
                    low[parent] = min(own, child)
                }
                guard low[top.game] == found[top.game] else { continue }
                while let member = stack.popLast() {
                    onStack.remove(member)
                    component[member] = components
                    if member == top.game { break }
                }
                components += 1
            }
        }
        var listedFromOutside = Set<Int>()
        for game in games {
            for part in parts[game] where among.contains(part) && component[part] != component[game] {
                if let listed = component[part] { listedFromOutside.insert(listed) }
            }
        }
        var heads: [Int: Int] = [:]
        for game in games {
            guard let own = component[game], !listedFromOutside.contains(own) else { continue }
            heads[own] = min(heads[own] ?? game, game)
        }
        return heads.values.sorted()
    }

    /// The games a sheet's or playlist's `part` is: the game in the file it names, a symbolic link
    /// followed (`followed(_:)`). Games that are one file by hard links (`paths`, each by its path with links resolved)
    /// each have a name of their own, so the part is the one whose path it spells. Resolving gives a path
    /// the file's own spelling, so a part named in another case still spells one; where it doesn't, the
    /// part is the one it spells but for case, and one it spells in neither way is all of them, as it
    /// can't be told which.
    private static func games(named part: URL, paths: [Int: String], index: [FileKey: [Int]]) -> [Int] {
        let sharing = index[FileKey(followed(part))] ?? []
        guard sharing.count > 1 else { return sharing }
        let spelled = part.resolvingSymlinksInPath().path
        let exact = sharing.filter { paths[$0] == spelled }
        if !exact.isEmpty { return exact }
        let caseAside = sharing.filter { paths[$0]?.caseInsensitiveCompare(spelled) == .orderedSame }
        return caseAside.isEmpty ? sharing : caseAside
    }

    /// A file as the file system knows it — its resource identifier, the same whatever the spelling that
    /// reached it — or, where it has none to give (a file that isn't there), its standardized path. A
    /// symbolic link is a file of its own here: `games(named:paths:index:)` follows one first.
    private enum FileKey: Hashable {
        case file(NSObject)
        case path(String)

        init(_ url: URL) {
            if let file = (try? url.resourceValues(forKeys: [.fileResourceIdentifierKey]))?.fileResourceIdentifier as? NSObject {
                self = .file(file)
            } else {
                self = .path(GameRecord.standardizedPath(of: url))
            }
        }
    }

    /// The record of the game in the file at `url`, added at `added` (to the whole second), for the
    /// library to keep — or, for Locate…, to keep a game by (`Library.relocate(_:to:)`): its name and
    /// folder, as the standardized path spells them; its format, by its extension (another kept as
    /// `.unknown`); a bookmark to it; its size — the file's own, with the tracks a .cue names and the
    /// discs an .m3u lists, a part that can't be sized counting nothing — and the names of a .cue's
    /// tracks or an .m3u's discs. Throws when the file itself can't be bookmarked or sized.
    public static func record(for url: URL, added: Date) throws(KeptFileError) -> GameRecord {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let bookmark = try KeptFile.bookmark(for: url)
        let ownSize = try KeptFile.size(at: url)
        let format = GameFormat(fileName: url.lastPathComponent) ?? .unknown(url.pathExtension.lowercased())
        var size = ownSize
        var tracks: [String] = []
        var discs: [String] = []
        switch format {
        case .cue where ownSize <= playlistLimit:
            let files = Playlists.cueTracks(url)
            tracks = files.map(\.lastPathComponent)
            size += files.reduce(0) { $0 + sizeOrNothing($1) }
        case .m3u where ownSize <= playlistLimit:
            let entries = Playlists.m3uEntries(url)
            discs = entries.map(\.lastPathComponent)
            size += entries.reduce(0) { total, disc in
                total + sizeOrNothing(disc) + parts(of: disc).reduce(0) { $0 + sizeOrNothing($1) }
            }
        default:
            break
        }
        let file = url.standardizedFileURL
        return GameRecord(
            fileName: file.lastPathComponent, folder: file.deletingLastPathComponent().path, format: format,
            size: size, added: Library.wholeSecond(added), bookmark: bookmark, tracks: tracks, discs: discs
        )
    }

    /// The files that come with the game at `url`: a .cue's tracks; an .m3u's discs and their tracks;
    /// nothing for another file, or for a playlist too big to be one. A cue sheet reached by a symbolic
    /// link names its tracks from the folder of the sheet it leads to.
    static func parts(of url: URL) -> [URL] {
        switch GameFormat(fileName: url.lastPathComponent) {
        case .cue?:
            guard sizeOrNothing(url) <= playlistLimit else { return [] }
            return Playlists.cueTracks(followed(url))
        case .m3u?:
            guard sizeOrNothing(url) <= playlistLimit else { return [] }
            return Playlists.m3uEntries(url).flatMap { disc -> [URL] in
                guard GameFormat(fileName: disc.lastPathComponent) == .cue, sizeOrNothing(disc) <= playlistLimit else { return [disc] }
                return [disc] + Playlists.cueTracks(followed(disc))
            }
        default:
            return []
        }
    }

    /// `url`, or, where it is a symbolic link, the file it leads to. Only a link is resolved, since resolving
    /// costs a look at every folder on the path.
    private static func followed(_ url: URL) -> URL {
        (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == true ? url.resolvingSymlinksInPath() : url
    }

    /// The size of the file at `url`, or 0 when it can't be sized: a track or disc that isn't there.
    private static func sizeOrNothing(_ url: URL) -> Int {
        (try? KeptFile.size(at: url)) ?? 0
    }
}
