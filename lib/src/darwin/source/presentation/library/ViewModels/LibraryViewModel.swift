// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import BusinessPS1
import BusinessSession
import DataLibrary
import Foundation
import Observation
import PresentationStyles

/// The library window, as the design draws it at the Today level (boards `Mac-LibraryEmpty`,
/// `Mac-TodayLibrary`, `Mac-LibraryGrid`, `Mac-LibraryInspector`, `Mac-LibrarySearchEmpty`,
/// `Mac-LibraryMissing`, `Mac-RemoveConfirm`, `Mac-Rename`, `Mac-LibraryMin`): the sidebar's places, the
/// games a place shows and the search over them, the selection, the table or the grid, Game info, and
/// what a person can do with a game — play it, rename it, remove it (asking first), find its file again
/// (Locate…), and add more (Add Games…, and Add Folder…'s scan). Until 5h reads discs a disc's console
/// and serial are "Unknown" and only a PS-EXE plays; a file that can't be found is flagged, never dropped.
///
/// It owns the place's two jobs: `scan`, Add Folder…'s, and `opening`, a PS-EXE's, which powers the
/// player's session on and hands the run to `onRun` as a `GameRun` — the app gives it to the player as its
/// run, so this module knows nothing of the player, as features never import each other (ADR 0023). Both
/// tell the library each change they make, so a game a scan adds shows at once and a game played shows when.
@MainActor
@Observable
public final class LibraryViewModel {
    /// How the games are laid out: the table, or the grid of tiles.
    public enum ViewMode: String, Sendable, CaseIterable {
        /// The table, a row a game.
        case list
        /// The grid of tiles, initials in place of artwork.
        case grid
    }

    /// What a place that lists games shows.
    public enum Content: Equatable, Sendable {
        /// The library keeps no game: "Add your games" (`Mac-LibraryEmpty`).
        case empty
        /// The library keeps games but the place or the search shows none, with what to say:
        /// "No games match “zebra”." (`Mac-LibrarySearchEmpty`) or "No games here yet.".
        case noResults(String)
        /// The games, in the table or the grid.
        case games
    }

    /// Whether a game can play now, and why not.
    public struct Playability: Equatable, Sendable {
        /// Whether Play applies.
        public var canPlay: Bool
        /// Why it doesn't, as Game info says under Play: "Discs play from v0.2.0."; nil when it does.
        public var reason: String?
    }

    /// The games the library keeps, in the order they were added.
    public private(set) var games: [GameRecord] = []
    /// The sidebar's place that shows.
    public private(set) var place: LibraryPlace = .allGames
    /// The search's words, which the search field binds; empty for none.
    public var query = ""
    /// The selected game, which the table and the grid bind; nil for none.
    public var selection: GameRecord.ID?
    /// The table or the grid, which the toolbar's buttons choose.
    public var viewMode: ViewMode = .list
    /// Whether the person asked for Game info (⌘I); it shows while a game is selected (`showsInfo`).
    public var isShowingInfo = false
    /// Whether the person wants the sidebar (⌃⌘S); a narrow window with Game info hides it (`layout(windowWidth:)`).
    public var isShowingSidebar = true
    /// Whether Add Games…'s chooser is open, for several files; the view binds `.fileImporter` to it and
    /// the person's choice comes back through `add(_:)`.
    public var isChoosingGames = false
    /// Whether Locate…'s chooser is open, for one file; the choice comes back through `located(_:)`.
    public var isLocating = false
    /// The game whose rename sheet is open; nil while it's closed.
    public private(set) var renaming: GameRecord.ID?
    /// The rename sheet's field, which the view binds.
    public var renameDraft = ""
    /// What the library is asking or telling, while its alert is open.
    public private(set) var alert: LibraryAlert?
    /// Whether the search field has focus, as the view tells it (from macOS 15, where SwiftUI can follow
    /// the toolbar's field): Return and ⌘⌫ are then the field's, so Play's and Remove from Library…'s keys
    /// give way, as the design's keys leave a field alone.
    public var isSearchFocused = false
    /// Whether Add Games… is recording the files chosen.
    public var isAdding: Bool { pendingAdds > 0 }
    /// Where each game's file was found when the library last looked: a game missing from it is
    /// `.missing`; one not looked for yet isn't here and counts as found.
    public private(set) var whereabouts: [GameRecord.ID: KeptFile.Whereabouts] = [:]
    /// How many choices Add Games… is still recording: each waits for the one before, so none is dropped.
    private var pendingAdds = 0

    /// Add Folder…'s job.
    public let scan: ScanViewModel
    /// A PS-EXE's opening job.
    public let opening: OpeningViewModel

    private let storage: any LibraryStorage
    private let home: String?
    private let calendar: Calendar
    private let now: @Sendable () -> Date
    private let isCovered: @MainActor () -> Bool

    /// What the open alert asks about.
    private enum Subject {
        case remove(GameRecord.ID), missing(GameRecord.ID), notice
    }

    /// What became of a file the person chose, once looked at off the main actor.
    private enum Outcome: Sendable {
        /// Its record, to keep it by.
        case recorded(GameRecord)
        /// It couldn't be opened: what `GameFiles.record(for:added:)` threw.
        case unreadable(any Error)
        /// Its extension isn't one of a game's (`GameFormat.fileExtensions`): never recorded.
        case notAGame
    }

    @ObservationIgnored private var subject: Subject?
    /// The game Locate…'s chooser finds the file of.
    @ObservationIgnored private var locating: GameRecord.ID?
    /// The last look for the games' files, Add Games…'s records, and Locate…'s record.
    @ObservationIgnored private var checking: Task<Void, Never>?
    @ObservationIgnored private var adding: Task<Void, Never>?
    @ObservationIgnored private var finding: Task<Void, Never>?

    /// The library `storage` keeps — read now, so the window shows its games at once, the first one
    /// selected — whose opening job powers on `session`, the player's, and hands each run to `onRun`.
    /// Folders under `home` are written from "~"; dates are written in `calendar`, today being `now`'s
    /// day, and games are dated by `now`. A BIOS the opening job finds somewhere else goes to
    /// `onBIOSMoved`, for the BIOS pane. While `isCovered` says another screen's sheet, chooser or alert is
    /// over the window — the app's BIOS check and BIOS pane — the library's keys and buttons do nothing, as
    /// under its own. It looks for every game's file at once, off the main actor.
    public init(
        storage: any LibraryStorage, session: any ConsoleSessionPowerControls, home: String? = nil,
        calendar: Calendar = .current, now: @escaping @Sendable () -> Date = { Date() },
        isCovered: @escaping @MainActor () -> Bool = { false },
        onRun: @escaping @MainActor (GameRun) -> Void,
        onBIOSMoved: @escaping @MainActor (BIOSRecord) -> Void = { _ in }
    ) {
        let relay = Relay()
        self.storage = storage
        self.home = home
        self.calendar = calendar
        self.now = now
        self.isCovered = isCovered
        scan = ScanViewModel(storage: storage, home: home, now: now) { relay.library?.show($0) }
        opening = OpeningViewModel(
            storage: storage, session: session, now: now, onRun: onRun,
            onPlayed: { relay.library?.show($0) }, onBIOSMoved: onBIOSMoved
        )
        // An unreadable library shows no games, as the BIOS pane shows no BIOS: the store's refusal is
        // said when a change is tried.
        games = (try? storage.library())?.games ?? []
        selection = games.first?.id
        relay.library = self
        checkFiles()
    }

    deinit {
        checking?.cancel()
        adding?.cancel()
        finding?.cancel()
    }

    // MARK: - Places, search and selection

    /// Shows `place`: the sidebar, ⌘1, ⌘4 and ⌘6. A place that lists games selects its first one when
    /// the selection isn't among them; the BIOS closes Game info. Nothing while a sheet or alert shows.
    public func go(to place: LibraryPlace) {
        guard canAct else { return }
        self.place = place
        if !place.listsGames { isShowingInfo = false }
        let shown = shownGames
        if let first = shown.first, !shown.contains(where: { $0.id == selection }) { selection = first.id }
    }

    /// Selects game `id`, or none: a click in the table or the grid.
    public func select(_ id: GameRecord.ID?) {
        selection = id
    }

    /// Searches the games for `words`: what the person types in the search field.
    public func search(for words: String) {
        query = words
    }

    /// Empties the search: Clear Search.
    public func clearSearch() {
        query = ""
    }

    /// Lays the games out as `mode`: the toolbar's list and grid buttons, and the View menu's as List and
    /// as Grid.
    public func showGames(as mode: ViewMode) {
        viewMode = mode
    }

    /// Shows or hides Game info: ⌘I, and the toolbar's Game info. Only with a game selected.
    public func toggleInfo() {
        guard canToggleInfo else { return }
        isShowingInfo.toggle()
    }

    /// Shows or hides the sidebar: ⌃⌘S, and the toolbar's sidebar button.
    public func toggleSidebar() {
        isShowingSidebar.toggle()
    }

    /// The split view showed or hid the sidebar itself, as `shows` says. Hiding it while Game info shows
    /// is never the person's wish: it is the split view following the Layout page's breakpoint (Game info
    /// hides the sidebar in a window under 1,100 points) or making room, so the sidebar comes back once
    /// Game info closes or the window widens. Any other change, a drag of the split view's divider, is the
    /// person's, as ⌃⌘S is.
    public func splitViewShowsSidebar(_ shows: Bool) {
        if !shows && showsInfo { return }
        if isShowingSidebar != shows { isShowingSidebar = shows }
    }

    // MARK: - Adding games

    /// Opens Add Games…'s chooser: ⌘O, the toolbar's Add Games, and the empty library's button.
    public func chooseGames() {
        guard canAct else { return }
        isChoosingGames = true
    }

    /// Opens Add Folder…'s chooser: ⇧⌘O, the toolbar's Add Folder, and the empty library's button.
    public func chooseFolder() {
        guard canAct else { return }
        scan.chooseFolder()
    }

    /// Adds the files at `urls`, the ones the person chose: each is recorded off the main actor — its
    /// bookmark, its size, a .cue's tracks or an .m3u's discs — and the new ones added together. A file
    /// the library keeps already is passed over; the last file chosen is selected. A file that can't be
    /// opened, or isn't a .cue, .iso, .m3u or .exe file, opens an alert naming it, and is never recorded;
    /// the rest are added. Files chosen while an earlier choice is still being recorded are added after it.
    public func add(_ urls: [URL]) {
        isChoosingGames = false
        guard !urls.isEmpty else { return }
        pendingAdds += 1
        let storage = self.storage
        let date = now()
        let previous = adding
        adding = Task { [weak self] in
            await previous?.value
            guard let games = self?.games else { return }
            // Passed over: the files the library keeps by now, an earlier choice's included.
            let kept = Library(games: games)
            let fresh = urls.filter { kept.game(at: $0) == nil }
            // Linked to this task, so the library going away stops the files being recorded.
            let recording = Task.detached { () async -> [(URL, Outcome)] in
                var outcomes: [(URL, Outcome)] = []
                for url in fresh where !Task.isCancelled {
                    outcomes.append((url, await Self.outcome(of: url, added: date, from: storage)))
                }
                return outcomes
            }
            let outcomes = await withTaskCancellationHandler { await recording.value } onCancel: { recording.cancel() }
            self?.added(urls, outcomes)
        }
    }

    /// What became of the file at `url`, chosen at `date`: recorded, unless it isn't a game's file or
    /// can't be opened.
    private nonisolated static func outcome(of url: URL, added date: Date, from storage: any LibraryStorage) async -> Outcome {
        guard GameFormat(fileName: url.lastPathComponent) != nil else { return .notAGame }
        do {
            return .recorded(try await storage.record(for: url, added: date))
        } catch {
            return .unreadable(error)
        }
    }

    /// Adds the games recorded from the files chosen, `urls`, and says which couldn't be.
    private func added(_ urls: [URL], _ outcomes: [(URL, Outcome)]) {
        defer { pendingAdds -= 1 }
        var records: [GameRecord] = []
        var refused: [(URL, Outcome)] = []
        for (url, outcome) in outcomes {
            if case .recorded(let record) = outcome { records.append(record) } else { refused.append((url, outcome)) }
        }
        if !records.isEmpty {
            do {
                show(try storage.addGames(records).library)
            } catch {
                return tell(storeFailure("LibraryStore.addGames(_:)", error))
            }
        }
        let library = Library(games: games)
        if let last = urls.reversed().lazy.compactMap({ library.game(at: $0) }).first { selection = last.id }
        guard let first = refused.first else { return }
        let onlyNotGames = refused.allSatisfy { if case .notAGame = $0.1 { true } else { false } }
        tell(LibraryAlert(
            title: refused.count == 1 ? "“\(first.0.lastPathComponent)” couldn’t be added" : "\(Figures.grouped(refused.count)) files couldn’t be added",
            message: onlyNotGames ? LibraryText.onlyGameFiles
                : refused.count == 1 ? "iStation couldn’t open this file." : "iStation couldn’t open these files.",
            details: refused.map { Self.details($0.0, $0.1) }.joined(separator: "\n"),
            tone: .danger, buttons: [LibraryAlert.Button("OK", role: .primary, choice: .ok)]
        ))
    }

    /// The Details line for a file chosen at `url` that came to `outcome`: the call that refused it.
    private static func details(_ url: URL, _ outcome: Outcome) -> String {
        switch outcome {
        case .recorded: ""
        case .unreadable(let error): Details.threw("GameFiles.record(for:added:)", error)
        case .notAGame: "GameFormat(fileName: \"\(url.lastPathComponent)\") returned nil"
        }
    }

    // MARK: - Playing

    /// Plays game `id`, or the selected game: Play, Return and a double-click. A game whose file can't
    /// be found asks to Locate… it or remove it, as the design's missing dialog does; a PS-EXE opens;
    /// a disc does nothing until v0.2.0. Nothing while a sheet or alert shows.
    public func play(_ id: GameRecord.ID? = nil) {
        guard canAct, let game = id.flatMap(game(_:)) ?? selectedGame else { return }
        selection = game.id
        if case .missing(let error) = whereabouts[game.id] { return askAboutMissing(game, error) }
        guard playability(of: game).canPlay else { return }
        opening.open(game)
    }

    /// Whether `game` can play now: only a PS-EXE whose file is there, until discs play from v0.2.0.
    public func playability(of game: GameRecord) -> Playability {
        if game.format != .psexe { return Playability(canPlay: false, reason: LibraryText.discsPlayLater) }
        if isMissing(game) { return Playability(canPlay: false, reason: LibraryText.cantFindShort) }
        return Playability(canPlay: true, reason: nil)
    }

    /// Whether Play's key (Return) applies now: the selected game can play — or its file is missing, so
    /// Return asks to Locate… it or remove it, as the design's Return does — no sheet or alert shows, and
    /// the search field doesn't have Return for itself.
    public var canPlaySelected: Bool {
        guard canAct, !isSearchFocused, let game = selectedGame else { return false }
        return isMissing(game) || playability(of: game).canPlay
    }

    // MARK: - Removing

    /// Asks before taking game `id`, or the selected game, out of the library, as `Mac-RemoveConfirm`
    /// does, with what it deletes under Details: Remove from Library…, ⌘⌫. Nothing while a sheet or alert shows.
    public func askToRemove(_ id: GameRecord.ID? = nil) {
        guard canAct, let game = id.flatMap(game(_:)) ?? selectedGame else { return }
        let kind = game.format == .psexe ? "The program" : "The disc image"
        subject = .remove(game.id)
        alert = LibraryAlert(
            title: "Remove “\(game.shownName)” from your library?",
            message: "\(kind) stays on your Mac. You can add it again any time.",
            details: "Deletes its entry and bookmark from library.json in iStation’s container.\nLeaves \(shownPath(game)) untouched.",
            tone: .info,
            buttons: [LibraryAlert.Button("Cancel", role: .cancel, choice: .cancel), LibraryAlert.Button("Remove", role: .primary, choice: .remove)]
        )
    }

    /// Whether Remove from Library…'s key (⌘⌫) applies now: a game is selected, no sheet or alert shows,
    /// and the search field doesn't have ⌘⌫ for itself.
    public var canRemoveSelected: Bool { canAct && !isSearchFocused && selectedGame != nil }

    /// Answers the open alert with `choice`: Remove takes the game out, Locate… opens the chooser, and
    /// Cancel or OK closes it. Escape answers `.cancel`.
    public func answer(_ choice: LibraryAlert.Choice) {
        let subject = self.subject
        alert = nil
        self.subject = nil
        switch (subject, choice) {
        case (.remove(let id)?, .remove), (.missing(let id)?, .remove): remove(id)
        case (.missing(let id)?, .locate): startLocating(id)
        default: break
        }
    }

    /// Takes game `id` out of the library, leaving its file, and selects the first game shown.
    private func remove(_ id: GameRecord.ID) {
        do {
            show(try storage.removeGames([id]))
            selection = shownGames.first?.id ?? games.first?.id
        } catch {
            tell(storeFailure("LibraryStore.removeGames(_:)", error))
        }
    }

    // MARK: - Renaming

    /// Opens the rename sheet for game `id`, or the selected game, its field holding the name shown:
    /// Game info's pencil. Nothing while a sheet or alert shows.
    public func rename(_ id: GameRecord.ID? = nil) {
        guard canAct, let game = id.flatMap(game(_:)) ?? selectedGame else { return }
        renaming = game.id
        renameDraft = game.shownName
    }

    /// Whether the sheet's Rename applies: its field isn't blank.
    public var canSaveRename: Bool {
        !renameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Gives the game the field's name in the library — the file keeps its own — and closes the sheet:
    /// Rename. A name left as it was changes nothing; the file's own name takes the library's name away,
    /// so the game follows its file's name again.
    public func saveRename() {
        guard let id = renaming, let game = game(id), canSaveRename else { return }
        let name = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        renaming = nil
        guard name != game.shownName else { return }
        let stem = (game.fileName as NSString).deletingPathExtension
        do {
            show(try storage.renameGame(id, to: name == stem ? nil : name))
        } catch {
            tell(storeFailure("LibraryStore.renameGame(_:to:)", error))
        }
    }

    /// Closes the rename sheet, changing nothing: Cancel and Escape.
    public func cancelRename() {
        renaming = nil
    }

    // MARK: - Missing files and Locate…

    /// Opens Locate…'s chooser for game `id`, or the selected game: Game info's Locate…. Nothing while a
    /// sheet or alert shows.
    public func locate(_ id: GameRecord.ID? = nil) {
        guard canAct, let game = id.flatMap(game(_:)) ?? selectedGame else { return }
        startLocating(game.id)
    }

    /// Keeps the game Locate… was for by the file at `url`, the one the person chose: recorded off the
    /// main actor, then kept with its own name and dates. A file that can't be opened, that isn't a .cue,
    /// .iso, .m3u or .exe file, or that another game is kept by, opens an alert and changes nothing.
    public func located(_ url: URL) {
        isLocating = false
        guard let id = locating, let game = game(id) else { return }
        locating = nil
        let storage = self.storage
        let added = game.added
        let previous = finding
        finding = Task { [weak self] in
            await previous?.value
            let outcome = await Task.detached { await Self.outcome(of: url, added: added, from: storage) }.value
            self?.relocate(id, to: outcome, from: url)
        }
    }

    /// Looks for every game's file again, off the main actor: one that can't be found is flagged
    /// missing, and stays; one found somewhere else is kept again quietly by where it is now, as Run the
    /// BIOS keeps a moved BIOS. When the library opens, and whenever the app asks.
    public func checkFiles() {
        let games = self.games
        let storage = self.storage
        let previous = checking
        checking = Task { [weak self] in
            await previous?.value
            // Linked to this task, so the library going away ends the look at the game it is on.
            let look = Task.detached { () async -> [(GameRecord, KeptFile.Whereabouts, GameRecord?)] in
                var looked: [(GameRecord, KeptFile.Whereabouts, GameRecord?)] = []
                for game in games where !Task.isCancelled {
                    let whereabouts = storage.whereabouts(of: game)
                    guard case .moved(let url) = whereabouts else {
                        looked.append((game, whereabouts, nil))
                        continue
                    }
                    looked.append((game, whereabouts, try? await storage.record(for: url, added: game.added)))
                }
                return looked
            }
            let looked = await withTaskCancellationHandler { await look.value } onCancel: { look.cancel() }
            self?.looked(looked)
        }
    }

    /// Notes where each game's file was found, keeping the moved ones by their new places in one change to
    /// `library.json`, however many moved: a folder of games renamed is one load and one save, not one a game.
    private func looked(_ looked: [(GameRecord, KeptFile.Whereabouts, GameRecord?)]) {
        var moves: [GameRecord.ID: GameRecord] = [:]
        for (game, whereabouts, record) in looked {
            // A game removed, located or found meanwhile is as the library now has it.
            guard self.game(game.id)?.bookmark == game.bookmark else { continue }
            switch whereabouts {
            case .found, .missing:
                self.whereabouts[game.id] = whereabouts
            case .moved(let url):
                self.whereabouts[game.id] = .found(url)
                if let record { moves[game.id] = record }
            }
        }
        guard !moves.isEmpty, let library = try? storage.relocateGames(moves) else { return }
        show(library)
    }

    /// The selected game's file, where its bookmark leads now, for Show in Finder; nil, and the game
    /// flagged missing, when it can't be found.
    public func fileToShowInFinder() -> URL? {
        guard let game = selectedGame else { return nil }
        do {
            return try storage.resolve(game.bookmark).url
        } catch {
            whereabouts[game.id] = .missing(error as? KeptFileError ?? .cannotResolve(reason: error.localizedDescription))
            return nil
        }
    }

    /// Whether `game`'s file couldn't be found when the library last looked.
    public func isMissing(_ game: GameRecord) -> Bool {
        if case .missing = whereabouts[game.id] { return true }
        return false
    }

    /// Opens the chooser to find game `id`'s file.
    private func startLocating(_ id: GameRecord.ID) {
        locating = id
        isLocating = true
    }

    /// Keeps game `id` by the file chosen at `url`, as `outcome` has it, or says why it can't.
    private func relocate(_ id: GameRecord.ID, to outcome: Outcome, from url: URL) {
        guard let game = game(id) else { return }
        let record: GameRecord
        switch outcome {
        case .recorded(let value): record = value
        case .unreadable:
            return tell(LibraryAlert(
                title: "“\(url.lastPathComponent)” couldn’t be opened", message: "iStation couldn’t open this file.",
                details: Self.details(url, outcome), tone: .danger,
                buttons: [LibraryAlert.Button("OK", role: .primary, choice: .ok)]
            ))
        case .notAGame:
            return tell(LibraryAlert(
                title: "“\(url.lastPathComponent)” isn’t a game’s file",
                message: LibraryText.onlyGameFiles + " Choose “\(game.fileName)” where it is now.",
                details: Self.details(url, outcome), tone: .warning,
                buttons: [LibraryAlert.Button("OK", role: .primary, choice: .ok)]
            ))
        }
        do {
            show(try storage.relocateGame(id, to: record))
            whereabouts[id] = .found(url)
        } catch LibraryStoreError.noSuchGame {
            // Removed while the file was read: there is nothing to keep it by.
        } catch LibraryStoreError.alreadyKept(let path) {
            let other = games.first { $0.path == path }
            tell(LibraryAlert(
                title: "That file is already in your library",
                message: "Your library keeps it as “\(other?.shownName ?? record.fileName)”. Choose “\(game.fileName)” where it is now.",
                details: Details.threw("LibraryStore.relocateGame(_:to:)", LibraryStoreError.alreadyKept(path: path)), tone: .warning,
                buttons: [LibraryAlert.Button("OK", role: .primary, choice: .ok)]
            ))
        } catch {
            tell(storeFailure("LibraryStore.relocateGame(_:to:)", error))
        }
    }

    /// Asks what to do about `game`, whose file can't be found, with what the library found under Details.
    private func askAboutMissing(_ game: GameRecord, _ error: KeptFileError) {
        // A bookmark that resolves to a file that can't be sized failed at the size; any other, at the resolve.
        let call = switch error {
        case .cannotRead: "KeptFile.size(at:)"
        case .cannotResolve, .cannotBookmark: "KeptFile.resolve(_:)"
        }
        let gone = "It may have been moved, renamed or deleted."
        subject = .missing(game.id)
        alert = LibraryAlert(
            title: "iStation can’t find “\(game.fileName)”",
            message: game.folder.isEmpty ? gone : "It was in \(shownFolder(game)). " + gone,
            details: Details.threw(call, error), tone: .warning,
            buttons: [
                LibraryAlert.Button("Remove from Library", role: .secondary, choice: .remove),
                LibraryAlert.Button("Locate…", role: .primary, choice: .locate),
            ]
        )
    }

    // MARK: - What the window shows

    /// The selected game; nil for none.
    public var selectedGame: GameRecord? {
        selection.flatMap(game(_:))
    }

    /// The games the place shows, the search's words matching their names in any case: every game for
    /// All Games, in the order added; the games played for Recently Played, the most recent first; none
    /// for the BIOS.
    public var shownGames: [GameRecord] {
        guard place.listsGames else { return [] }
        var shown = games
        if place == .recentlyPlayed {
            // The most recent first, games played at the same second in the order added.
            shown = shown.enumerated()
                .filter { $0.element.lastPlayed != nil }
                .sorted {
                    ($0.element.lastPlayed ?? .distantPast, $1.offset) > ($1.element.lastPlayed ?? .distantPast, $0.offset)
                }
                .map(\.element)
        }
        let words = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !words.isEmpty else { return shown }
        return shown.filter { $0.shownName.range(of: words, options: .caseInsensitive) != nil }
    }

    /// What the place shows: the empty library, no results, or the games.
    public var content: Content {
        if games.isEmpty { return .empty }
        guard shownGames.isEmpty else { return .games }
        let words = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return .noResults(words.isEmpty ? LibraryText.noGamesHere : LibraryText.noGamesMatch(words))
    }

    /// The table's rows and the grid's tiles, for the games shown.
    public var rows: [GameRow] {
        shownGames.map(row(for:))
    }

    /// Game info for the selected game; nil for none.
    public var info: GameInfo? {
        selectedGame.map(info(for:))
    }

    /// Whether Game info shows: asked for, with a game selected, in a place that lists games.
    public var showsInfo: Bool {
        isShowingInfo && selectedGame != nil && place.listsGames
    }

    /// Whether the toolbar's Game info and ⌘I apply: a game is selected.
    public var canToggleInfo: Bool { selectedGame != nil && place.listsGames }

    /// The window's layout at `windowWidth`, the Layout page's breakpoints applied.
    public func layout(windowWidth: CGFloat) -> LibraryLayout {
        LibraryLayout(windowWidth: windowWidth, wantsSidebar: isShowingSidebar, showsInfo: showsInfo)
    }

    /// Whether the note that discs can't be read or played yet shows: once the library keeps a game.
    public var showsTodayBanner: Bool { !games.isEmpty && place.listsGames }

    /// How many games the sidebar counts beside `place`; nil for the BIOS, which counts none.
    public func count(of place: LibraryPlace) -> Int? {
        switch place {
        case .allGames: return games.count
        case .recentlyPlayed: return games.count { $0.lastPlayed != nil }
        case .bios: return nil
        }
    }

    /// The window's title: the place's name.
    public var windowTitle: String { place.title }

    /// The window's subtitle over a place that lists games: how many it shows, "6 games"; the BIOS pane
    /// gives its own.
    public var windowSubtitle: String {
        place.listsGames ? LibraryText.games(shownGames.count) : ""
    }

    /// The sidebar button's name and tooltip, which say what pressing it does.
    public var sidebarButton: (title: String, help: String) {
        isShowingSidebar
            ? (LibraryText.hideSidebar, LibraryText.hideSidebarHelp)
            : (LibraryText.showSidebar, LibraryText.showSidebarHelp)
    }

    /// Whether a sheet, chooser or alert is open over the library — the scan's, the opening's, the rename
    /// sheet, a chooser — so its keys and buttons do nothing, as the design's do under a sheet.
    public var isShowingSheet: Bool {
        scan.isShowingJob || opening.isShowingJob || scan.isChoosingFolder || renaming != nil || alert != nil
            || isChoosingGames || isLocating
    }

    /// Whether the library's keys and buttons act now: no sheet, chooser or alert is open, the library's
    /// own or another screen's over the window (`isCovered`).
    public var canAct: Bool { !isShowingSheet && !isCovered() }

    /// Whether the player holds the window rather than the library, and with it the Game menu's own items,
    /// while the player says a run plays (`isPlaying`, which the app reads from the player): unless an
    /// opening job is still handing one over, or stopping the console a job it cancelled powered on. Once
    /// the player has followed one run it follows the session across a stop, so from the second PS-EXE on
    /// it plays before the hand-off, while the opening sheet still shows over the library, and after a
    /// Cancel until the stop lands.
    public func playerHoldsWindow(whilePlaying isPlaying: Bool) -> Bool {
        isPlaying && !opening.isShowingJob && !opening.isStopping
    }

    /// The kept game `id` names; nil for none.
    public func game(_ id: GameRecord.ID) -> GameRecord? {
        games.first { $0.id == id }
    }

    /// `game` as its table row and grid tile show it.
    public func row(for game: GameRecord) -> GameRow {
        let known = game.format == .psexe
        let missing = isMissing(game)
        let console = known ? PS1Console.name : LibraryText.unknown
        let flag = missing ? LibraryText.fileMissing : nil
        let played = LibraryText.played(game.lastPlayed, in: calendar, today: now())
        return GameRow(
            id: game.id, name: game.shownName, symbol: known ? Symbols.program : Symbols.disc,
            console: console, consoleEmphasis: known ? .plain : .muted,
            serial: known ? LibraryText.none : LibraryText.unknown, serialEmphasis: .muted,
            format: LibraryText.formatCell(game.format),
            size: missing ? LibraryText.unknown : LibraryText.size(game.size),
            lastPlayed: played, flag: flag, flagTone: missing ? .warning : nil,
            accessibilityLabel: [game.shownName, console, flag].compactMap { $0 }.joined(separator: ", "),
            initials: LibraryText.initials(game.shownName), consoleBadge: known ? PS1Console.name : "?",
            serialBadge: known ? LibraryText.psexe : "",
            tileCaption: flag ?? (game.lastPlayed == nil ? "Never played" : "Played " + played)
        )
    }

    /// `game` as Game info shows it.
    public func info(for game: GameRecord) -> GameInfo {
        let known = game.format == .psexe
        let missing = isMissing(game)
        let today = now()
        let playability = playability(of: game)
        let facts = [
            GameInfo.Fact("Console", known ? PS1Console.name : LibraryText.consoleUntilRead, style: known ? .plain : .muted),
            GameInfo.Fact("Serial", known ? LibraryText.noSerial : LibraryText.unknown, style: .monospaced),
            GameInfo.Fact("Format", LibraryText.formatFact(game)),
            GameInfo.Fact("Size", missing ? LibraryText.unknown : LibraryText.size(game.size)),
            GameInfo.Fact("File", game.fileName, style: .monospaced),
            GameInfo.Fact("Folder", shownFolder(game), style: .monospaced),
            GameInfo.Fact("Added", LibraryText.added(game.added, in: calendar, today: today)),
            GameInfo.Fact("Last played", LibraryText.played(game.lastPlayed, in: calendar, today: today)),
        ]
        return GameInfo(
            id: game.id, name: game.shownName, initials: LibraryText.initials(game.shownName), facts: facts,
            banner: missing ? LibraryText.cantFindFile : nil, bannerTone: missing ? .warning : nil,
            action: missing ? .locate : .play,
            actionTitle: missing ? LibraryText.locate : LibraryText.play,
            actionHelp: missing ? LibraryText.locateHelp : LibraryText.playHelp,
            isActionEnabled: missing || playability.canPlay,
            reason: missing ? nil : playability.reason,
            canShowInFinder: !missing
        )
    }

    // MARK: - Changes

    /// Shows `library`, as a store call, the scan or the opening job left it: a game no longer kept is
    /// no longer selected, and no longer looked for.
    func show(_ library: Library) {
        games = library.games
        let ids = Set(games.map(\.id))
        if let selection, !ids.contains(selection) { self.selection = nil }
        whereabouts = whereabouts.filter { ids.contains($0.key) }
    }

    /// Opens `alert`, which only tells.
    private func tell(_ alert: LibraryAlert) {
        subject = .notice
        self.alert = alert
    }

    /// The alert for a change `library.json` couldn't take.
    private func storeFailure(_ call: String, _ error: any Error) -> LibraryAlert {
        LibraryAlert(
            title: "The library couldn’t be saved",
            message: "iStation couldn’t write the change to its library. Your files are as they were.",
            details: Details.threw(call, error), tone: .danger,
            buttons: [LibraryAlert.Button("OK", role: .primary, choice: .ok)]
        )
    }

    /// The folder `game`'s file is in, from "~" under the home folder; "Unknown" when the record didn't
    /// keep it.
    private func shownFolder(_ game: GameRecord) -> String {
        game.folder.isEmpty ? LibraryText.unknown : Folders.shown(game.folder, home: home)
    }

    /// `game`'s file, its folder from "~": "~/Games/PS1/Glass Orchard (Europe).cue".
    private func shownPath(_ game: GameRecord) -> String {
        game.folder.isEmpty ? game.fileName : Folders.shown(game.folder, home: home) + "/" + game.fileName
    }

    /// Waits until every look, add and locate under way, and both jobs, have finished; the tests' way to know.
    func settled() async {
        await checking?.value
        await adding?.value
        await finding?.value
        await scan.settled()
        await opening.settled()
    }
}

/// The library's two jobs are made before it is, so they reach it through this, set once it is made.
@MainActor
private final class Relay {
    weak var library: LibraryViewModel?
}
