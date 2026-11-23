// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import BusinessPS1
import DataLibrary
import Foundation
@testable import PresentationLibrary
import PresentationStyles
import Testing

/// A PS-EXE's opening job over an in-memory library, a made-up PS-EXE and BIOS built in code, and a
/// scripted console session: its three steps to the hand-off — the session powered on with the BIOS and
/// the program before the run is handed on, and only once the boot is no longer pending — and every way
/// it fails: a file that isn't a PS-EXE or can't be found, the BIOS missing, unreadable or of the wrong
/// size, a BIOS that never reaches its shell. Every wait ends after two seconds.
@MainActor
@Suite struct OpeningViewModelTests {
    func makeOpening(_ storage: MemoryStorage, _ session: FakePowerSession, _ handed: Handed, log: EventLog? = nil) -> OpeningViewModel {
        OpeningViewModel(
            storage: storage, session: session, now: { today },
            onRun: { run in
                log?.note("handed on")
                handed.runs.append(run)
            },
            onPlayed: { handed.libraries.append($0) },
            onBIOSMoved: { handed.moved.append($0) }
        )
    }

    /// The sample PS-EXE; one the library doesn't keep when it's gone, so the expectations on it fail
    /// rather than the run trapping.
    func program(_ storage: MemoryStorage) -> GameRecord {
        storage.saved.games.first { $0.format == .psexe } ?? game(URL(fileURLWithPath: "/gone/gpu-test.exe"))
    }

    /// Opens the sample PS-EXE and waits for it to fail, returning the job's state.
    func failure(_ storage: MemoryStorage, _ game: GameRecord? = nil) async -> (OpeningViewModel, FakePowerSession) {
        let session = FakePowerSession()
        let opening = makeOpening(storage, session, Handed())
        opening.open(game ?? program(storage))
        #expect(await settled(opening))
        return (opening, session)
    }

    // MARK: The way to the hand-off

    @Test func aPSEXEPowersOnWithTheBIOSAndTheProgramThenTheRunIsHandedOn() async throws {
        let log = EventLog()
        let session = FakePowerSession(log: log)
        let storage = sampleStorage()
        let handed = Handed()
        let opening = makeOpening(storage, session, handed, log: log)
        let game = program(storage)
        opening.open(game)
        #expect(opening.state == .running(.open))
        #expect(opening.isShowingJob)

        #expect(await followed(session))
        #expect(opening.state == .running(.start))
        #expect(await session.controls == [.powerOn(bytes: 524_288, exe: true)])
        let expected = try PSEXE(bytes: programImage)
        let bios = await session.bios
        #expect(bios == biosImage, "powered on with the kept BIOS's bytes")
        #expect(await session.exe == expected)
        #expect(handed.runs.isEmpty, "the boot is pending until the BIOS reaches its shell")

        await session.run(to: 30)
        try await Task.sleep(for: .milliseconds(20))
        #expect(opening.state == .running(.start))
        #expect(handed.runs.isEmpty)

        await session.run(to: 90, reachedShell: true)
        #expect(await eventually { opening.state == .idle })
        #expect(handed.runs == [GameRun(biosFileName: "my-console-bios.bin", biosSize: 524_288, name: "gpu-test", fileName: "gpu-test.exe")])
        #expect(log.noted == ["powered on", "handed on"], "powered on with the BIOS and the program before the hand-off")
        #expect(!opening.isShowingJob)
        #expect(opening.job == nil)
        #expect(storage.saved.game(game.id)?.lastPlayed == today.roundedDown, "the game is noted as played")
        #expect(handed.libraries.count == 1)
        #expect(await settled(opening))
        #expect(await session.controls == [.powerOn(bytes: 524_288, exe: true)], "the run goes on in the player")
    }

    @Test func theSheetShowsTheDesignsThreeSteps() async throws {
        let session = FakePowerSession()
        await session.holdPowerOns()
        let storage = sampleStorage()
        let opening = makeOpening(storage, session, Handed())
        opening.open(program(storage))
        var job = try #require(opening.job)
        #expect(job.title == "Opening gpu-test")
        #expect(job.steps.map(\.name) == ["Open the file", "Power on with your BIOS", "Start the program"])
        #expect(job.steps.map(\.detail) == ["gpu-test.exe", "my-console-bios.bin", "Once the BIOS reaches its shell"])
        #expect(job.steps.map(\.state) == [.running, .pending, .pending])
        #expect(job.actions == [JobPresentation.Action("Cancel", role: .stop)])
        #expect(job.stopAction?.help == "Cancel (⌘.)")
        #expect(job.summary == nil)
        #expect(job.progress == nil)

        #expect(await holding(1, session))
        job = try #require(opening.job)
        #expect(opening.state == .running(.powerOn))
        #expect(job.steps.map(\.state) == [.done, .running, .pending])

        await session.letGo()
        #expect(await followed(session))
        job = try #require(opening.job)
        #expect(job.steps.map(\.state) == [.done, .done, .running])
        await session.run(to: 60, reachedShell: true)
        #expect(await settled(opening))
    }

    @Test func aDiscIsntOpened() async {
        let session = FakePowerSession()
        let storage = sampleStorage()
        let opening = makeOpening(storage, session, Handed())
        opening.open(storage.saved.games[0])
        #expect(opening.state == .idle)
        #expect(await settled(opening))
        #expect(await session.calls.isEmpty)
    }

    @Test func openingWhileAJobShowsDoesNothing() async {
        let session = FakePowerSession()
        await session.holdPowerOns()
        let storage = sampleStorage()
        let opening = makeOpening(storage, session, Handed())
        opening.open(program(storage))
        #expect(await holding(1, session))
        opening.open(program(storage))
        await session.letGo()
        #expect(await followed(session))
        #expect(await session.controls == [.powerOn(bytes: 524_288, exe: true)])
        opening.cancel()
        #expect(await settled(opening))
    }

    @Test func aBIOSFoundSomewhereElseIsKeptAgainWhereItIsNow() async {
        let session = FakePowerSession()
        let storage = sampleStorage()
        storage.move(Files.bios, to: Files.biosElsewhere)
        let handed = Handed()
        let opening = makeOpening(storage, session, handed)
        opening.open(program(storage))
        #expect(await followed(session))
        #expect(storage.saved.bios?.folder == "/Volumes/Archive/Console")
        #expect(storage.saved.bios?.bookmark == Data(Files.biosElsewhere.path.utf8))
        #expect(handed.moved.map(\.folder) == ["/Volumes/Archive/Console"], "the BIOS pane hears where it is now")
        await session.run(to: 60, reachedShell: true)
        #expect(await eventually { handed.runs.count == 1 })
        #expect(handed.runs.first?.biosFileName == "my-console-bios.bin")
    }

    @Test func aGameThatCantBeNotedPlayedStillPlays() async {
        let session = FakePowerSession()
        let storage = sampleStorage()
        let handed = Handed()
        let opening = makeOpening(storage, session, handed)
        opening.open(program(storage))
        #expect(await followed(session))
        storage.fail(.init(write: .cannotWrite(path: "/x/library.json", reason: "The disk is full.")))
        await session.run(to: 60, reachedShell: true)
        #expect(await eventually { handed.runs.count == 1 })
        #expect(handed.libraries.isEmpty)
        #expect(opening.state == .idle)
    }

    // MARK: The program's file

    @Test func aFileThatIsntAPSEXEIsRefusedAtOpenTheFile() async throws {
        let storage = sampleStorage(games: sampleGames() + [game(Files.notAProgram)])
        storage.put([UInt8](repeating: 0, count: 10), at: Files.notAProgram)
        let readme = storage.saved.games[6]
        var (opening, session) = await failure(storage, readme)
        #expect(opening.state == .failed(.open, .notAProgram(details: "PSEXE(bytes:) threw PSEXEError.tooShort")))
        let job = try #require(opening.job)
        #expect(job.title == "Opening readme")
        #expect(job.steps.map(\.state) == [.failed, .pending, .pending])
        #expect(job.summary == JobPresentation.Summary("This file isn’t a PS-EXE program, so iStation can’t start it.", tone: .danger))
        #expect(job.output == "PSEXE(bytes:) threw PSEXEError.tooShort")
        #expect(job.actions == [JobPresentation.Action("Close", role: .close)])
        #expect(await session.calls.isEmpty, "nothing is powered on")

        storage.put([UInt8](repeating: 0, count: 4_096), at: Files.notAProgram)
        (opening, session) = await failure(storage, readme)
        #expect(opening.state == .failed(.open, .notAProgram(details: "PSEXE(bytes:) threw PSEXEError.notAnEXE")))
        opening.close()
        #expect(opening.state == .idle)
    }

    @Test func aFileTooBigToBeAPSEXEIsRefusedUnread() async {
        let storage = sampleStorage()
        storage.put([UInt8](repeating: 0, count: OpeningViewModel.largestProgram + 1), at: Files.gpuTest)
        let (opening, session) = await failure(storage)
        #expect(opening.state == .failed(.open, .notAProgram(
            details: "PSEXE(bytes:) wasn’t called: the file is 2,099,201 bytes, more than a PS-EXE’s 2,099,200"
        )))
        #expect(storage.reads(of: Files.gpuTest) == 0, "never read whole")
        #expect(await session.calls.isEmpty)
    }

    @Test func aProgramWhoseFileIsGoneOrUnreadableIsRefused() async {
        var storage = sampleStorage()
        storage.delete(Files.gpuTest)
        var (opening, _) = await failure(storage)
        #expect(opening.state == .failed(.open, .missing(details: #"KeptFile.resolve(_:) threw KeptFileError.cannotResolve(reason: "No such file.")"#)))
        #expect(opening.job?.summary?.text == "iStation can’t find this file. It may have been moved, renamed or deleted.")

        storage = sampleStorage()
        storage.fail(.init(bytes: .cannotRead(path: Files.gpuTest.path, reason: "Permission denied.")))
        (opening, _) = await failure(storage)
        #expect(opening.state == .failed(.open, .unreadable(
            details: #"KeptFile.bytes(at:) threw KeptFileError.cannotRead(path: "/Users/you/Games/Homebrew/gpu-test.exe", reason: "Permission denied.")"#
        )))
        #expect(opening.job?.summary?.text == "iStation couldn’t open this file.")
    }

    // MARK: The BIOS

    @Test func noBIOSKeptIsRefusedAtPowerOn() async {
        let storage = sampleStorage()
        let games = storage.saved.games
        let bare = MemoryStorage(library: Library(games: games), files: [Files.gpuTest: programImage])
        let (opening, session) = await failure(bare)
        #expect(opening.state == .failed(.powerOn, .noBIOS(details: nil)))
        #expect(opening.job?.summary?.text == "iStation has no BIOS to power on with. Choose your BIOS file first.")
        #expect(opening.job?.steps.map(\.state) == [.done, .failed, .pending])
        #expect(await session.calls.isEmpty)
    }

    @Test func aLibraryThatCantBeReadIsRefusedAtPowerOn() async {
        let storage = sampleStorage()
        let game = program(storage)
        storage.fail(.init(load: .cannotRead(path: "/x/library.json", reason: "Gone.")))
        let (opening, _) = await failure(storage, game)
        #expect(opening.state == .failed(.powerOn, .noBIOS(
            details: #"LibraryStore.load() threw LibraryStoreError.cannotRead(path: "/x/library.json", reason: "Gone.")"#
        )))
    }

    @Test func aBIOSThatCantBeFoundOrReadIsRefusedAtPowerOn() async {
        var storage = sampleStorage()
        storage.delete(Files.bios)
        var (opening, session) = await failure(storage)
        #expect(opening.state == .failed(.powerOn, .biosUnreadable(
            name: "my-console-bios.bin", details: #"KeptFile.resolve(_:) threw KeptFileError.cannotResolve(reason: "No such file.")"#
        )))
        #expect(opening.job?.summary?.text == "iStation couldn’t open my-console-bios.bin where you keep it. Put it back, or choose it again.")
        #expect(await session.calls.isEmpty)

        let gone = KeptFileError.cannotRead(path: Files.bios.path, reason: "Gone.")
        let threw = #"threw KeptFileError.cannotRead(path: "/Users/you/Documents/Console/my-console-bios.bin", reason: "Gone.")"#
        storage = sampleStorage()
        storage.fail(.init(sizeOf: ["my-console-bios.bin": gone]))
        (opening, session) = await failure(storage)
        #expect(opening.state == .failed(.powerOn, .biosUnreadable(name: "my-console-bios.bin", details: "KeptFile.size(at:) " + threw)))
        #expect(await session.calls.isEmpty)

        storage = sampleStorage()
        storage.fail(.init(bytesOf: ["my-console-bios.bin": gone]))
        (opening, session) = await failure(storage)
        #expect(opening.state == .failed(.powerOn, .biosUnreadable(name: "my-console-bios.bin", details: "KeptFile.bytes(at:) " + threw)))
        #expect(await session.calls.isEmpty)
    }

    @Test func aBIOSOfTheWrongSizeIsRefusedUnread() async {
        let storage = sampleStorage()
        storage.put([UInt8](repeating: 1, count: 271_384), at: Files.bios)
        let (opening, session) = await failure(storage)
        #expect(opening.state == .failed(.powerOn, .biosWrongSize(
            name: "my-console-bios.bin", bytes: 271_384, details: "PS1Console.powerOn(bios:) threw PS1Error.biosSize(271384)"
        )))
        #expect(opening.job?.summary?.text == "my-console-bios.bin is now 271,384 bytes. A PS1 BIOS is exactly 524,288 bytes. Choose the BIOS file itself.")
        #expect(opening.job?.output == "PS1Console.powerOn(bios:) threw PS1Error.biosSize(271384)")
        #expect(storage.reads(of: Files.bios) == 0, "refused before it is read")
        #expect(await session.calls.isEmpty)
    }

    @Test func aBIOSThatNeverReachesItsShellIsGivenUpOnAtFrame600() async throws {
        let session = FakePowerSession()
        let storage = sampleStorage()
        let handed = Handed()
        let opening = makeOpening(storage, session, handed)
        opening.open(program(storage))
        #expect(await followed(session))
        await session.run(to: 599)
        try await Task.sleep(for: .milliseconds(20))
        #expect(opening.state == .running(.start))
        await session.run(to: 600)
        #expect(await eventually { opening.state == .failed(.start, .noShell) })
        #expect(await session.controls == [.powerOn(bytes: 524_288, exe: true), .stop], "the console is released")
        #expect(opening.job?.summary?.text == "Your BIOS didn’t reach its shell in 600 frames, so the program didn’t start.")
        #expect(opening.job?.output == "PS1Console.bootIsPending stayed true: the shell (0x80030000) wasn’t reached by frame 600")
        #expect(opening.job?.steps.map(\.state) == [.done, .done, .failed])
        #expect(handed.runs.isEmpty)
        #expect(storage.saved.game(program(storage).id)?.lastPlayed == moment(2026, 11, 18), "not noted as played")
    }

    // MARK: Cancel

    @Test func cancelBeforePowerOnClosesTheSheetAndPowersNothingOn() async {
        let session = FakePowerSession()
        let storage = sampleStorage()
        let opening = makeOpening(storage, session, Handed())
        opening.open(program(storage))
        opening.perform(JobPresentation.Action("Cancel", role: .stop))
        #expect(opening.state == .idle, "the design's Cancel closes the sheet")
        #expect(await settled(opening))
        #expect(await session.calls.isEmpty)
    }

    @Test func cancelWhileTheBIOSIsReadPowersNothingOn() async {
        let session = FakePowerSession()
        let storage = sampleStorage()
        storage.holdReads(of: "my-console-bios.bin")
        let handed = Handed()
        let opening = makeOpening(storage, session, handed)
        opening.open(program(storage))
        #expect(await waiting(1, storage))
        #expect(opening.state == .running(.powerOn))
        opening.cancel()
        #expect(opening.state == .idle)
        storage.letAllGo()
        #expect(await settled(opening))
        #expect(storage.reads(of: Files.bios) == 1, "the read under way ends")
        #expect(await session.calls.isEmpty, "a job cancelled before its power-on powers nothing on, so stops nothing")
        #expect(handed.runs.isEmpty)
    }

    @Test func cancelWhilePoweringOnStopsTheSession() async {
        let session = FakePowerSession()
        await session.holdPowerOns()
        let storage = sampleStorage()
        let handed = Handed()
        let opening = makeOpening(storage, session, handed)
        opening.open(program(storage))
        #expect(await holding(1, session))
        opening.cancel()
        #expect(opening.state == .idle)
        // Cancel's stop reaches the session while its power-on is still under way, and the power-on lands
        // after it: the job's own stop, once the power-on returns, is what leaves the session stopped.
        #expect(await recorded(1, .stop, session))
        await session.letGo()
        #expect(await settled(opening))
        #expect(await session.controls == [.powerOn(bytes: 524_288, exe: true), .stop, .stop])
        #expect(await session.current.state == .stopped)
        #expect(handed.runs.isEmpty)
    }

    @Test func aJobOpenedRightAfterACancelStartsOnceTheCancelsStopHasLanded() async {
        let session = FakePowerSession()
        let storage = sampleStorage()
        let handed = Handed()
        let opening = makeOpening(storage, session, handed)
        opening.open(program(storage))
        #expect(await followed(session))
        await session.holdStops()
        opening.cancel()
        #expect(await holdingStops(1, session))
        opening.open(program(storage))
        #expect(opening.state == .running(.open))
        try? await Task.sleep(for: .milliseconds(50))
        #expect(await session.controls == [.powerOn(bytes: 524_288, exe: true)], "the new job waits for the old one's stop")

        await session.letStopsGo()
        #expect(await recorded(2, .powerOn(bytes: 524_288, exe: true), session))
        #expect(await eventually { opening.state == .running(.start) })
        #expect(await session.controls == [.powerOn(bytes: 524_288, exe: true), .stop, .powerOn(bytes: 524_288, exe: true)])
        #expect(await session.current.state == .running, "the old job's stop didn't stop the new job's console")
        await session.run(to: 60, reachedShell: true)
        #expect(await eventually { handed.runs.count == 1 })
        #expect(await settled(opening))
    }

    @Test func cancelWhileWaitingForTheShellStopsTheSessionAndHandsNothingOn() async {
        let session = FakePowerSession()
        let storage = sampleStorage()
        let handed = Handed()
        let opening = makeOpening(storage, session, handed)
        opening.open(program(storage))
        #expect(await followed(session))
        opening.dismiss()
        #expect(opening.state == .idle)
        #expect(await settled(opening))
        #expect(await session.controls == [.powerOn(bytes: 524_288, exe: true), .stop])
        await session.run(to: 60, reachedShell: true)
        try? await Task.sleep(for: .milliseconds(20))
        #expect(handed.runs.isEmpty)
        #expect(storage.saved.game(program(storage).id)?.lastPlayed == moment(2026, 11, 18))
    }

    @Test func aSessionStoppedUnderTheJobEndsIt() async {
        let session = FakePowerSession()
        let storage = sampleStorage()
        let handed = Handed()
        let opening = makeOpening(storage, session, handed)
        opening.open(program(storage))
        #expect(await followed(session))
        await session.stop()
        #expect(await eventually { opening.state == .idle })
        #expect(handed.runs.isEmpty)
    }

    @Test func closingAFailedSheetClosesIt() async {
        let storage = sampleStorage()
        storage.delete(Files.gpuTest)
        let (opening, _) = await failure(storage)
        #expect(opening.isShowingJob)
        opening.dismiss()
        #expect(opening.state == .idle)
    }
}
