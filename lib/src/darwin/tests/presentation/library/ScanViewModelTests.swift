// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import DataLibrary
import Foundation
@testable import PresentationLibrary
import PresentationStyles
import SupportSandbox
import Testing

/// Add Folder…'s scan over a folder of made-up games built in a `Sandbox` — tiny cue sheets, playlists and
/// tracks of a few bytes, never a disc image — and a library held in memory: the .cue, .iso, .m3u and
/// .exe files it finds in the folder and its subfolders, one entry for an .m3u and its discs and none for
/// a .cue's .bin tracks; its steps as the design's boards draw them; Stop mid-way; Scan Again with no
/// duplicates; and the files that can't be added. Every wait ends after two seconds.
@MainActor
@Suite struct ScanViewModelTests {
    func makeScan(_ storage: MemoryStorage, sandbox: Sandbox, handed: Handed = Handed()) -> ScanViewModel {
        ScanViewModel(storage: storage, home: GameRecord.standardizedPath(of: sandbox.root), now: { today }) {
            handed.libraries.append($0)
        }
    }

    func makeStorage(_ sandbox: Sandbox) -> MemoryStorage {
        MemoryStorage(library: Library(bios: keptBIOS), disk: sandbox.root)
    }

    // MARK: What the scan finds

    @Test func aScanAddsTheGamesItFindsInTheFolderAndItsSubfolders() async throws {
        let sandbox = try Sandbox()
        let folder = try makeGames(in: sandbox)
        let storage = makeStorage(sandbox)
        let handed = Handed()
        let scan = makeScan(storage, sandbox: sandbox, handed: handed)
        scan.scan(folder)
        #expect(await settled(scan))
        #expect(scan.state == .done)
        #expect(scan.results.map(\.file) == foundGames)
        #expect(scan.results.allSatisfy { $0.outcome == .added })
        #expect(storage.saved.games.map(\.fileName) == ["gpu-test.exe", "Glass Orchard (Europe).cue", "Harbor Lights (USA).cue", "Moonbase Courier.iso", "Tidepool.m3u"])
        #expect(storage.saved.games.map(\.format) == [.psexe, .cue, .cue, .iso, .m3u])
        #expect(scan.added == storage.saved.games)
        #expect(handed.libraries.count == 5, "the library hears each game as it joins")
        #expect(handed.libraries.last?.games == storage.saved.games)
        #expect(storage.saved.bios == keptBIOS, "the BIOS is kept as it was")
    }

    @Test func anM3uAndItsDiscsAreOneEntry() async throws {
        let sandbox = try Sandbox()
        let folder = try makeGames(in: sandbox)
        let storage = makeStorage(sandbox)
        let scan = makeScan(storage, sandbox: sandbox)
        scan.scan(folder)
        #expect(await settled(scan))
        let names = storage.saved.games.map(\.fileName)
        #expect(!names.contains("Tidepool (Disc 1).cue"))
        #expect(!names.contains("Tidepool (Disc 2).iso"))
        let tidepool = storage.saved.games.first { $0.format == .m3u }
        #expect(tidepool?.discs == ["Tidepool (Disc 1).cue", "Tidepool (Disc 2).iso"])
        let parts = ["Tidepool.m3u", "Tidepool (Disc 1).cue", "Tidepool (Disc 1).bin", "Tidepool (Disc 2).iso"]
        let size = try parts.reduce(0) { total, name in
            let path = folder.appendingPathComponent("PS1/Tidepool/\(name)").path
            return total + ((try FileManager.default.attributesOfItem(atPath: path)[.size] as? NSNumber)?.intValue ?? 0)
        }
        #expect(tidepool?.size == size, "the playlist, its discs and their tracks")
        #expect(scan.results.map(\.file).filter { $0.hasPrefix("PS1/Tidepool/") } == ["PS1/Tidepool/Tidepool.m3u"])
    }

    @Test func aCuesBinTracksAreNoEntry() async throws {
        let sandbox = try Sandbox()
        let folder = try makeGames(in: sandbox)
        let storage = makeStorage(sandbox)
        let scan = makeScan(storage, sandbox: sandbox)
        scan.scan(folder)
        #expect(await settled(scan))
        #expect(!storage.saved.games.contains { $0.fileName.hasSuffix(".bin") })
        #expect(!scan.results.contains { $0.file.hasSuffix(".bin") })
        let harbor = storage.saved.games.first { $0.fileName == "Harbor Lights (USA).cue" }
        #expect(harbor?.tracks == ["Harbor Lights (USA) (Track 1).bin", "Harbor Lights (USA) (Track 2).bin"])
        #expect(!storage.saved.games.contains { $0.fileName == "readme.txt" })
    }

    // MARK: Its steps

    @Test func aFinishedScanTalliesWhatCameOfEachFile() async throws {
        let sandbox = try Sandbox()
        let folder = try makeGames(in: sandbox)
        let scan = makeScan(makeStorage(sandbox), sandbox: sandbox)
        scan.scan(folder)
        #expect(await settled(scan))
        let job = try #require(scan.job)
        #expect(job.title == "Adding games from ~/Games")
        #expect(job.subtitle == nil)
        #expect(job.steps.map(\.name) == ["Find disc images", "Read each disc", "Add them to your library"])
        #expect(job.steps.map(\.state) == [.done, .done, .done])
        #expect(job.steps.map(\.detail) == ["5 found", "5 of 5", nil])
        #expect(job.progress == nil)
        #expect(job.summary == JobPresentation.Summary("Added 5 games.", tone: .ok))
        #expect(job.results.map(\.note) == ["Added · PS-EXE · no serial", "Added · .cue", "Added · .cue", "Added · .iso", "Added · .m3u"])
        #expect(job.actions == [JobPresentation.Action("Done", role: .finish)])
        #expect(job.status == .done)
        scan.perform(JobPresentation.Action("Done", role: .finish))
        #expect(scan.state == .idle)
        #expect(scan.job == nil)
    }

    @Test func whileItSearchesTheFirstStepSaysWhatItLooksFor() async throws {
        let sandbox = try Sandbox()
        let folder = try makeGames(in: sandbox)
        let storage = makeStorage(sandbox)
        storage.holdSearch()
        let scan = makeScan(storage, sandbox: sandbox)
        scan.scan(folder)
        #expect(await eventually { storage.calls.contains(.games("Games")) })
        let job = try #require(scan.job)
        #expect(scan.state == .running(.find))
        #expect(job.steps.map(\.state) == [.running, .pending, .pending])
        #expect(job.steps[0].detail == "Looking for .cue, .iso, .m3u and .exe files")
        #expect(job.steps[1].detail == nil, "before 5h the read step reads no SYSTEM.CNF, and doesn't say it will")
        #expect(job.actions == [JobPresentation.Action("Stop", role: .stop)])
        #expect(job.stopAction?.help == "Stop (⌘.)")
        storage.letAllGo()
        #expect(await settled(scan))
    }

    @Test func whileItReadsTheBarNamesTheFileBeingRead() async throws {
        let sandbox = try Sandbox()
        let folder = try makeGames(in: sandbox)
        let storage = makeStorage(sandbox)
        storage.holdRecords()
        let scan = makeScan(storage, sandbox: sandbox)
        scan.scan(folder)
        #expect(await waiting(1, storage))
        #expect(scan.state == .running(.read))
        var job = try #require(scan.job)
        #expect(job.steps.map(\.state) == [.done, .running, .pending])
        #expect(job.steps.map(\.detail) == ["5 found", "0 of 5", nil])
        #expect(job.progress == JobPresentation.Progress(.count(0, of: 5), label: "Discs read", text: "Reading 1 of 5 · Homebrew/gpu-test.exe"))
        storage.letGo()
        #expect(await eventually { scan.results.count == 1 })
        #expect(await waiting(1, storage))
        job = try #require(scan.job)
        #expect(job.steps[1].detail == "1 of 5")
        #expect(job.progress?.text == "Reading 2 of 5 · PS1/Glass Orchard (Europe).cue")
        #expect(job.results.map(\.file) == ["Homebrew/gpu-test.exe"])
        storage.letAllGo()
        #expect(await settled(scan))
    }

    // MARK: Stop and Scan Again

    @Test func stopEndsTheScanWhereItIsAndKeepsTheGamesAdded() async throws {
        let sandbox = try Sandbox()
        let folder = try makeGames(in: sandbox)
        let storage = makeStorage(sandbox)
        storage.holdRecords()
        let scan = makeScan(storage, sandbox: sandbox)
        scan.scan(folder)
        for read in 1...2 {
            #expect(await waiting(1, storage))
            storage.letGo()
            #expect(await eventually { scan.results.count == read })
        }
        #expect(await waiting(1, storage), "the third file is being read")
        scan.stop()
        #expect(scan.state == .stopped(.read))
        let job = try #require(scan.job)
        #expect(job.steps.map(\.state) == [.done, .stopped, .pending])
        #expect(job.summary == JobPresentation.Summary(
            "Stopped after 2 of 5. Added 2 games. Scan Again skips the games already added.", tone: .warning
        ))
        #expect(job.actions == [JobPresentation.Action("Done", role: .close), JobPresentation.Action("Scan Again", role: .retry)])
        storage.letAllGo()
        #expect(await settled(scan))
        #expect(scan.results.count == 2, "the file being read when it stopped isn't added")
        #expect(storage.saved.games.count == 2)
        #expect(storage.openAccess == 0, "the folder's access ends with the scan")
    }

    @Test func aScanStoppedBeforeAnyFileStartsOverOnScanAgain() async throws {
        let sandbox = try Sandbox()
        let folder = try makeGames(in: sandbox)
        let storage = makeStorage(sandbox)
        storage.holdSearch()
        let scan = makeScan(storage, sandbox: sandbox)
        scan.scan(folder)
        #expect(await eventually { storage.calls.contains(.games("Games")) })
        scan.stop()
        #expect(scan.state == .stopped(.find))
        #expect(scan.job?.summary == JobPresentation.Summary("Stopped before reading any disc. Scan Again starts over.", tone: .warning))
        #expect(scan.job?.steps.map(\.state) == [.stopped, .pending, .pending])
        #expect(await settled(scan), "a stop ends the search")
        #expect(storage.saved.games.isEmpty)
        #expect(storage.openAccess == 0)
    }

    @Test func scanAgainPassesOverTheGamesAddedAndAddsNoneTwice() async throws {
        let sandbox = try Sandbox()
        let folder = try makeGames(in: sandbox)
        let storage = makeStorage(sandbox)
        storage.holdRecords()
        let scan = makeScan(storage, sandbox: sandbox)
        scan.scan(folder)
        for read in 1...2 {
            #expect(await waiting(1, storage))
            storage.letGo()
            #expect(await eventually { scan.results.count == read })
        }
        #expect(await waiting(1, storage), "the third file is being read")
        scan.stop()
        storage.letAllGo()
        #expect(await settled(scan))

        scan.perform(JobPresentation.Action("Scan Again", role: .retry))
        #expect(scan.isRunning)
        #expect(await settled(scan))
        #expect(scan.state == .done)
        #expect(scan.results.map(\.file) == foundGames)
        #expect(scan.results.map(\.outcome) == [.skipped, .skipped, .added, .added, .added])
        #expect(scan.results.first?.note == "Already in your library")
        #expect(scan.job?.summary?.text == "Added 3 games. 2 already in your library.")
        #expect(storage.saved.games.count == 5)
        #expect(Set(storage.saved.games.map(\.path)).count == 5, "no game twice")
        #expect(storage.calls.count { if case .record = $0 { true } else { false } } == 6, "a game kept already isn't read again")

        scan.scanAgain()
        #expect(await settled(scan))
        #expect(scan.results.allSatisfy { $0.outcome == .skipped })
        #expect(scan.job?.summary?.text == "5 already in your library.")
        #expect(storage.saved.games.count == 5)
    }

    // MARK: Files and folders that can't be added

    @Test func aFileThatCantBeOpenedIsListedAndTheRestAreAdded() async throws {
        let sandbox = try Sandbox()
        let folder = try makeGames(in: sandbox)
        let storage = makeStorage(sandbox)
        storage.fail(.init(record: ["Moonbase Courier.iso": .cannotRead(path: "Moonbase Courier.iso", reason: "Permission denied.")]))
        let scan = makeScan(storage, sandbox: sandbox)
        scan.scan(folder)
        #expect(await settled(scan))
        #expect(scan.state == .done)
        try #require(scan.results.count == 5)
        let moonbase = scan.results[3]
        #expect(moonbase.file == "PS1/Moonbase Courier.iso")
        #expect(moonbase.outcome == .failed)
        #expect(moonbase.note == "iStation couldn’t open this file.")
        #expect(moonbase.code == "KeptFileError.cannotRead")
        #expect(scan.job?.summary == JobPresentation.Summary("Added 4 games. 1 couldn’t be added.", tone: .ok))
        #expect(storage.saved.games.count == 4)
    }

    @Test func aGameTheLibraryCantKeepIsListed() async throws {
        let sandbox = try Sandbox()
        let folder = try makeGames(in: sandbox)
        let storage = makeStorage(sandbox)
        storage.fail(.init(write: .cannotWrite(path: "/x/library.json", reason: "The disk is full.")))
        let scan = makeScan(storage, sandbox: sandbox)
        scan.scan(folder)
        #expect(await settled(scan))
        #expect(scan.results.allSatisfy { $0.outcome == .failed && $0.note == "iStation couldn’t add this game to your library." })
        #expect(scan.results.first?.code == "LibraryStoreError.cannotWrite")
        #expect(scan.job?.summary?.text == "5 couldn’t be added.")
    }

    @Test func aFolderThatCantBeSearchedFailsTheScan() async throws {
        let sandbox = try Sandbox()
        let storage = makeStorage(sandbox)
        let scan = makeScan(storage, sandbox: sandbox)
        scan.scan(sandbox.url("Nowhere"))
        #expect(await settled(scan))
        guard case .failed(.find, let details) = scan.state else {
            Issue.record("the scan didn't fail at its search: \(scan.state)")
            return
        }
        #expect(details.hasPrefix("GameFiles.find(in:) threw KeptFileError.cannotRead(path: "))
        let job = try #require(scan.job)
        #expect(job.steps.map(\.state) == [.failed, .pending, .pending])
        #expect(job.summary == JobPresentation.Summary("iStation couldn’t open this folder.", tone: .danger))
        #expect(job.output == details)
        #expect(job.actions == [JobPresentation.Action("Done", role: .close), JobPresentation.Action("Scan Again", role: .retry)])
        #expect(storage.openAccess == 0)
    }

    @Test func theFoldersAccessIsHeldFromTheSearchUntilTheLastFileIsRecorded() async throws {
        let sandbox = try Sandbox()
        let folder = try makeGames(in: sandbox)
        let storage = makeStorage(sandbox)
        let scan = makeScan(storage, sandbox: sandbox)
        scan.scan(folder)
        #expect(await settled(scan))
        let calls = storage.calls
        let started = try #require(calls.firstIndex(of: .startAccessing("Games")))
        let searched = try #require(calls.firstIndex(of: .games("Games")))
        let lastRecord = try #require(calls.lastIndex { if case .record = $0 { true } else { false } })
        let stopped = try #require(calls.firstIndex(of: .stopAccessing("Games")))
        #expect(started < searched)
        #expect(lastRecord < stopped)
        #expect(storage.openAccess == 0)
    }

    // MARK: The chooser and the sheet

    @Test func theChooserOpensOnlyWhileNoScanShows() async throws {
        let sandbox = try Sandbox()
        let folder = try makeGames(in: sandbox)
        let storage = makeStorage(sandbox)
        storage.holdRecords()
        let scan = makeScan(storage, sandbox: sandbox)
        #expect(scan.canChooseFolder)
        scan.chooseFolder()
        #expect(scan.isChoosingFolder)
        scan.scan(folder)
        #expect(!scan.isChoosingFolder)
        #expect(scan.isShowingJob)
        scan.chooseFolder()
        #expect(!scan.isChoosingFolder, "Add Folder… does nothing under the sheet")
        scan.scan(folder)
        #expect(await waiting(1, storage))
        #expect(storage.calls.count { $0 == .games("Games") } == 1, "a scan doesn't start while one runs")
        storage.letAllGo()
        #expect(await settled(scan))
        #expect(!scan.canChooseFolder, "the done sheet still shows")
        scan.close()
        #expect(scan.canChooseFolder)
    }

    @Test func closingTheSheetStopsARunningScanAndClosesAnEndedOne() async throws {
        let sandbox = try Sandbox()
        let folder = try makeGames(in: sandbox)
        let storage = makeStorage(sandbox)
        storage.holdRecords()
        let scan = makeScan(storage, sandbox: sandbox)
        scan.scan(folder)
        #expect(await waiting(1, storage))
        scan.dismiss()
        #expect(scan.state == .stopped(.read), "Escape stops a running scan, and its sheet stays")
        scan.dismiss()
        #expect(scan.state == .idle)
        storage.letAllGo()
        #expect(await settled(scan))
    }

    @Test func scansHeldOnTheirFilesHoldNoThread() async throws {
        // More scans held on a file than Swift's pool has threads: were each held on a thread, nothing else
        // would run beside them, the other suites' tests included.
        let game = URL(fileURLWithPath: "/Users/you/Games/Moonbase Courier.iso")
        let storage = MemoryStorage(library: Library(bios: keptBIOS), files: [game: [1, 2, 3]])
        storage.holdRecords()
        let count = ProcessInfo.processInfo.activeProcessorCount + 1
        let scans = (0..<count).map { _ in
            ScanViewModel(storage: storage, home: Files.home, now: { today }) { _ in }
        }
        for scan in scans { scan.scan(game.deletingLastPathComponent()) }
        #expect(await waiting(count, storage), "every scan reads its file")
        let ran = Ran()
        Task.detached { await MainActor.run { ran.isSet = true } }
        #expect(await eventually { ran.isSet }, "a task still runs beside them")
        storage.letAllGo()
        for scan in scans { #expect(await settled(scan)) }
        #expect(storage.saved.games.count == 1)
    }

    @Test func theLibraryShowsEachGameAsTheScanAddsIt() async throws {
        let sandbox = try Sandbox()
        let folder = try makeGames(in: sandbox)
        let storage = makeStorage(sandbox)
        storage.holdRecords()
        let library = LibraryViewModel(
            storage: storage, session: FakePowerSession(), home: GameRecord.standardizedPath(of: sandbox.root),
            calendar: utc, now: { today }, onRun: { _ in }
        )
        #expect(library.content == .empty)
        library.chooseFolder()
        #expect(library.scan.isChoosingFolder)
        #expect(library.isShowingSheet)
        library.scan.scan(folder)
        #expect(await waiting(1, storage))
        storage.letGo()
        #expect(await eventually { library.games.count == 1 })
        #expect(library.content == .games)
        #expect(!library.canAct, "the scan's sheet shows")
        storage.letAllGo()
        #expect(await settled(library))
        #expect(library.rows.map(\.name) == ["gpu-test", "Glass Orchard (Europe)", "Harbor Lights (USA)", "Moonbase Courier", "Tidepool"])
        #expect(library.rows.map(\.format) == ["PS-EXE", ".cue", ".cue", ".iso", ".m3u"])
        library.scan.close()
        #expect(library.canAct)
    }
}
