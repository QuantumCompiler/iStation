// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import DataLibrary
import Foundation

/// Where the library's view-models reach files: the games and the BIOS `library.json` keeps, the files the
/// person chose — found, sized and read where they keep them through their bookmarks — and the games a
/// folder holds. The app hands in `LibraryStoreStorage`, over the library's `LibraryStore`, `KeptFile` and
/// `GameFiles`; previews and tests hand in one held in memory, so no view-model test touches a file it
/// didn't build in a `Sandbox`.
///
/// Every call but `record(for:added:)` is synchronous, as the store's and the kept files' are: the
/// view-models choose where each runs — the person's files off the main actor; `library.json`, the app's
/// own small file, on it, so its changes are made one at a time. A record is asynchronous, so a stand-in
/// can hold one where it is — a preview's scan stays on its fifth file — without holding a thread. Resolving a bookmark, sizing a file and reading it are
/// `KeptFileReading`'s, which this refines, so the opening job reads the BIOS through the library's own
/// `readBIOS(_:expectedSize:)` and the library tells a missing file by `whereabouts(of:)`.
public protocol LibraryStorage: KeptFileReading {
    /// The library as `library.json` holds it now: an empty one before the file exists.
    func library() throws -> Library

    /// Adds each of `games` the library doesn't keep yet, skipping a file it keeps already
    /// (`LibraryStore.addGames(_:)`).
    func addGames(_ games: [GameRecord]) throws -> LibraryStore.Added

    /// Gives game `id` the name `name` in the library alone; nil or empty takes it away
    /// (`LibraryStore.renameGame(_:to:)`).
    func renameGame(_ id: GameRecord.ID, to name: String?) throws -> Library

    /// Takes the games `ids` names out of the library, leaving their files where they are
    /// (`LibraryStore.removeGames(_:)`).
    func removeGames(_ ids: Set<GameRecord.ID>) throws -> Library

    /// Notes that game `id` was played at `date` (`LibraryStore.markPlayed(_:at:)`).
    func markPlayed(_ id: GameRecord.ID, at date: Date) throws -> Library

    /// Keeps game `id` by `file`, the record of where its file is now (`LibraryStore.relocateGame(_:to:)`).
    func relocateGame(_ id: GameRecord.ID, to file: GameRecord) throws -> Library

    /// Keeps each game `moves` names by its file's record where it is now, in one change: a game no longer
    /// kept, or whose file is another game's, is passed over (`LibraryStore.relocateGames(_:)`).
    func relocateGames(_ moves: [GameRecord.ID: GameRecord]) throws -> Library

    /// Keeps `record` as the library's BIOS, in place of the one before (`LibraryStore.keepBIOS(_:)`).
    func keepBIOS(_ record: BIOSRecord) throws -> Library

    /// A bookmark to the file at `url`, to keep it by (`KeptFile.bookmark(for:)`).
    func bookmark(for url: URL) throws -> Data

    /// The games in `folder` and its subfolders, in path order: one entry for an .m3u and its discs, none
    /// for a .cue's tracks (`GameFiles.find(in:)`). A cancelled task's search ends early.
    func games(in folder: URL) throws -> [URL]

    /// The record of the game in the file at `url`, added at `added` (`GameFiles.record(for:added:)`). The
    /// view-models call it off the main actor.
    func record(for url: URL, added: Date) async throws -> GameRecord

    /// Starts the security-scoped access the file chooser gave `url`, a folder whose files are reached
    /// through it; true when there was access to start, and `stopAccessing(_:)` is then owed.
    func startAccessing(_ url: URL) -> Bool

    /// Ends the access `startAccessing(_:)` started.
    func stopAccessing(_ url: URL)
}

/// The library kept in the app's `library.json` through `LibraryStore`, and the person's files through
/// `KeptFile` and `GameFiles`, each inside its security-scoped access. The app builds it over the store at
/// its own container's `library.json`, the one the BIOS pane's `LibraryBIOSStorage` keeps the BIOS in.
public struct LibraryStoreStorage: LibraryStorage {
    /// The library the games are kept in.
    public let store: LibraryStore

    /// Storage keeping the games in `store`.
    public init(store: LibraryStore) {
        self.store = store
    }

    /// The library in `library.json`.
    public func library() throws -> Library {
        try store.load()
    }

    /// Adds `games`, skipping the files kept already, and saves.
    public func addGames(_ games: [GameRecord]) throws -> LibraryStore.Added {
        try store.addGames(games)
    }

    /// Renames game `id` in the library and saves.
    public func renameGame(_ id: GameRecord.ID, to name: String?) throws -> Library {
        try store.renameGame(id, to: name)
    }

    /// Removes the games `ids` names and saves; their files stay where they are.
    public func removeGames(_ ids: Set<GameRecord.ID>) throws -> Library {
        try store.removeGames(ids)
    }

    /// Notes when game `id` was played and saves.
    public func markPlayed(_ id: GameRecord.ID, at date: Date) throws -> Library {
        try store.markPlayed(id, at: date)
    }

    /// Keeps game `id` by `file` and saves.
    public func relocateGame(_ id: GameRecord.ID, to file: GameRecord) throws -> Library {
        try store.relocateGame(id, to: file)
    }

    /// Keeps each game `moves` names by its new record, and saves once.
    public func relocateGames(_ moves: [GameRecord.ID: GameRecord]) throws -> Library {
        try store.relocateGames(moves)
    }

    /// Keeps `record` as the BIOS and saves.
    public func keepBIOS(_ record: BIOSRecord) throws -> Library {
        try store.keepBIOS(record)
    }

    /// A bookmark to the file at `url`.
    public func bookmark(for url: URL) throws -> Data {
        try KeptFile.bookmark(for: url)
    }

    /// The games in `folder` and its subfolders.
    public func games(in folder: URL) throws -> [URL] {
        try GameFiles.find(in: folder)
    }

    /// The record of the game at `url`, read where the caller runs it.
    public func record(for url: URL, added: Date) async throws -> GameRecord {
        try GameFiles.record(for: url, added: added)
    }

    /// Starts `url`'s security-scoped access.
    public func startAccessing(_ url: URL) -> Bool {
        url.startAccessingSecurityScopedResource()
    }

    /// Ends `url`'s security-scoped access.
    public func stopAccessing(_ url: URL) {
        url.stopAccessingSecurityScopedResource()
    }

    /// Where `bookmark` leads now.
    public func resolve(_ bookmark: Data) throws -> KeptFile.Resolved {
        try KeptFile.resolve(bookmark)
    }

    /// The size of the file at `url`, without reading it.
    public func size(of url: URL) throws -> Int {
        try KeptFile.size(at: url)
    }

    /// The bytes of the file at `url`.
    public func bytes(of url: URL) throws -> [UInt8] {
        try KeptFile.bytes(at: url)
    }
}
