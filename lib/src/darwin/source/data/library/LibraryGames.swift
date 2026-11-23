// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import Foundation

/// The library's games changed in memory: what `LibraryStore`'s calls do between loading the file and
/// saving it, and what a view-model's fake library does without one. Each keeps the library's promise
/// of one game per file, and keeps its dates to the whole second, as the file does, so what a call
/// returns is what the next load reads. A game whose file can't be found is never dropped here: only
/// `remove(_:)` takes a game out.
extension Library {
    /// The kept game `id` names; nil for none.
    public func game(_ id: GameRecord.ID) -> GameRecord? {
        games.first { $0.id == id }
    }

    /// The kept game whose file is at `url` — compared by standardized path (`GameRecord.path`); nil for none.
    public func game(at url: URL) -> GameRecord? {
        let path = GameRecord.standardizedPath(of: url)
        return games.first { $0.path == path }
    }

    /// Adds each of `games` whose file the library doesn't keep yet, after the games kept before and in
    /// the order given: one already kept, by its file's standardized path, is skipped, and so is one
    /// that repeats a file earlier in `games` (or an id the library already has). Returns the games
    /// added, their dates to the whole second.
    @discardableResult
    public mutating func add(_ games: [GameRecord]) -> [GameRecord] {
        var paths = Set(self.games.map(\.path))
        var ids = Set(self.games.map(\.id))
        var added: [GameRecord] = []
        for var game in games {
            guard !paths.contains(game.path), !ids.contains(game.id) else { continue }
            paths.insert(game.path)
            ids.insert(game.id)
            game.added = Self.wholeSecond(game.added)
            game.lastPlayed = game.lastPlayed.map(Self.wholeSecond)
            added.append(game)
        }
        self.games += added
        return added
    }

    /// Gives game `id` the name `name` in the library, trimmed of spaces and new lines; an empty name, or
    /// nil, takes the library's name away, so the file's name shows again. The file keeps its own name.
    /// Returns the game renamed; throws `noSuchGame` when the library doesn't keep `id`.
    @discardableResult
    public mutating func rename(_ id: GameRecord.ID, to name: String?) throws(LibraryStoreError) -> GameRecord {
        let index = try index(of: id)
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        games[index].name = trimmed.isEmpty ? nil : trimmed
        return games[index]
    }

    /// Takes the games `ids` names out of the library, leaving their files where they are; an id the
    /// library doesn't keep is passed over. Returns the games taken out, in the library's order.
    @discardableResult
    public mutating func remove(_ ids: Set<GameRecord.ID>) -> [GameRecord] {
        let removed = games.filter { ids.contains($0.id) }
        games.removeAll { ids.contains($0.id) }
        return removed
    }

    /// Notes that game `id` was played at `date`, kept to the whole second. Returns the game; throws
    /// `noSuchGame` when the library doesn't keep `id`.
    @discardableResult
    public mutating func markPlayed(_ id: GameRecord.ID, at date: Date) throws(LibraryStoreError) -> GameRecord {
        let index = try index(of: id)
        games[index].lastPlayed = Self.wholeSecond(date)
        return games[index]
    }

    /// Game `id` found again as `file` — Locate…, or a bookmark that resolved stale: the game takes
    /// `file`'s name, folder, format, size, bookmark, tracks and discs, and keeps its own id, name, added
    /// and last-played dates. Returns the game; throws `noSuchGame` when the library doesn't keep `id`,
    /// and `alreadyKept` when `file` is another game's, since the library keeps one game per file.
    @discardableResult
    public mutating func relocate(_ id: GameRecord.ID, to file: GameRecord) throws(LibraryStoreError) -> GameRecord {
        let index = try index(of: id)
        if games.contains(where: { $0.id != id && $0.path == file.path }) { throw .alreadyKept(path: file.path) }
        games[index].fileName = file.fileName
        games[index].folder = file.folder
        games[index].format = file.format
        games[index].size = file.size
        games[index].bookmark = file.bookmark
        games[index].tracks = file.tracks
        games[index].discs = file.discs
        return games[index]
    }

    /// Each game `moves` names found again as its file's record there, as `relocate(_:to:)` keeps one, all
    /// in one change — the library's look finding a folder of games moved: a game the library no longer
    /// keeps, or whose file is another game's by then, is passed over and stays as it was. Returns the
    /// games relocated, in the library's order.
    @discardableResult
    public mutating func relocate(_ moves: [GameRecord.ID: GameRecord]) -> [GameRecord] {
        var relocated: [GameRecord] = []
        for game in games {
            guard let file = moves[game.id], let found = try? relocate(game.id, to: file) else { continue }
            relocated.append(found)
        }
        return relocated
    }

    /// Where game `id` is in `games`.
    private func index(of id: GameRecord.ID) throws(LibraryStoreError) -> Int {
        guard let index = games.firstIndex(where: { $0.id == id }) else { throw .noSuchGame(id) }
        return index
    }

    /// `date` rounded down to the whole second, as `library.json` keeps dates.
    static func wholeSecond(_ date: Date) -> Date {
        Date(timeIntervalSinceReferenceDate: date.timeIntervalSinceReferenceDate.rounded(.down))
    }
}
