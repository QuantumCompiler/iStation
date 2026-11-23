// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import BusinessPS1
import BusinessSession
import DataLibrary
import Foundation
@testable import PresentationBIOS
import PresentationStyles
import Testing

/// When the tests' checks keep a BIOS: a moment with a fraction of a second, which the record drops.
private let checkTime = Date(timeIntervalSinceReferenceDate: 816_000_000.75)

/// The steps as the sheet shows them: each one’s name, detail and state.
@MainActor
private func steps(_ check: BIOSCheckViewModel) -> [JobPresentation.Step] {
    check.job?.steps ?? []
}

@MainActor
@Suite struct BIOSCheckViewModelTests {
    let storage = FakeStorage(files: [
        Files.bios: biosImage,
        Files.copy: biosImage,
        Files.backup: [UInt8](repeating: 0, count: 271_384),
    ])
    let session = FakePowerSession()

    /// A check over this suite's storage and session, handing what it keeps to `kept`.
    func makeCheck(kept: @escaping @MainActor (BIOSRecord) -> Void = { _ in }) -> BIOSCheckViewModel {
        BIOSCheckViewModel(session: session, storage: storage, now: { checkTime }, onKept: kept)
    }

    /// A check of `file`, once it follows its session's frames.
    func following(_ file: URL, kept: @escaping @MainActor (BIOSRecord) -> Void = { _ in }) async -> BIOSCheckViewModel {
        let check = makeCheck(kept: kept)
        check.check(file)
        #expect(await followed(session), "the check never powered on and followed its session")
        return check
    }

    // MARK: - Before a check

    @Test func aNewCheckShowsNoSheet() async {
        let check = makeCheck()
        #expect(check.state == .idle)
        #expect(check.job == nil)
        #expect(!check.isChoosingFile)
        #expect(check.canChooseFile)
        check.stop()
        check.close()
        check.finish()
        #expect(check.state == .idle)
        #expect(await session.calls.isEmpty)
        #expect(storage.calls.isEmpty)
    }

    @Test func chooseBIOSFileOpensTheChooser() {
        let check = makeCheck()
        check.chooseFile()
        #expect(check.isChoosingFile)
        #expect(check.job == nil)
    }

    // MARK: - Each step

    @Test func aBIOSFileIsReadSizedAndFingerprintedThenPoweredOn() async {
        let check = await following(Files.bios)
        #expect(check.isChoosingFile == false)
        #expect(check.state == .running(.frames))
        let job = check.job
        #expect(job?.title == "Checking your BIOS")
        #expect(job?.subtitle == "my-console-bios.bin")
        let sha1 = Fingerprint.sha1(of: biosImage)
        #expect(check.sha1 == sha1)
        let fingerprint = "SHA-1 " + stride(from: 0, to: 40, by: 4).map { start in
            String(sha1.dropFirst(start).prefix(4))
        }.joined(separator: " ")
        #expect(steps(check) == [
            JobPresentation.Step("Read the file", detail: "524,288 bytes", state: .done),
            JobPresentation.Step("Check its size", detail: "A PS1 BIOS is 524,288 bytes (512 KB)", state: .done),
            JobPresentation.Step("Work out its fingerprint", detail: fingerprint, state: .done),
            JobPresentation.Step("Power on and run 60 frames", detail: "0 of 60 frames", state: .running),
            JobPresentation.Step("Reach the BIOS’s shell", state: .pending),
        ])
        #expect(job?.progress == JobPresentation.Progress(.count(0, of: 60), label: "Frames run", text: "0 of 60 frames"))
        #expect(job?.summary == nil)
        #expect(job?.output == nil)
        #expect(job?.actions == [JobPresentation.Action("Stop", role: .stop)])
        #expect(job?.stopAction?.help == "Stop (⌘.)")
        #expect(await session.controls == [.powerOn(bytes: 524_288, exe: false)])
        #expect(await session.bios == biosImage, "the check powers on with the file's own bytes")
        #expect(storage.calls == [.bookmark(Files.bios.path), .size(Files.bios.path), .bytes(Files.bios.path)])
    }

    @Test func theFramesCountUpTo60ThenTheShellStepRuns() async {
        let check = await following(Files.bios)
        await session.run(to: 24)
        #expect(await eventually { check.frame == 24 })
        #expect(steps(check)[3].detail == "24 of 60 frames")
        #expect(check.job?.progress == JobPresentation.Progress(.count(24, of: 60), label: "Frames run", text: "24 of 60 frames"))
        await session.run(to: 60)
        #expect(await eventually { check.state == .running(.shell) })
        #expect(steps(check).map(\.state) == [.done, .done, .done, .done, .running])
        #expect(steps(check)[3].detail == "60 of 60 frames")
        #expect(steps(check)[4].detail == nil, "the shell step has no detail, as the design draws it")
        #expect(check.job?.progress == nil)
        #expect(check.job?.actions == [JobPresentation.Action("Stop", role: .stop)])
        await session.run(to: 300)
        #expect(await eventually { check.frame == 300 })
        #expect(steps(check)[3].detail == "60 of 60 frames", "the frames step stops counting at its 60")
        #expect(check.state == .running(.shell))
    }

    // MARK: - Done

    @Test func aBIOSThatReachesItsShellIsKeptByItsBookmark() async {
        var handedOn: [BIOSRecord] = []
        let check = await following(Files.bios) { handedOn.append($0) }
        await session.run(to: 60)
        await session.run(to: 75, reachedShell: true)
        #expect(await eventually { check.state == .done })
        #expect(await settled(check))
        let record = BIOSRecord(
            fileName: "my-console-bios.bin", folder: "/Users/you/Documents/Console", size: 524_288,
            sha1: Fingerprint.sha1(of: biosImage), checked: Date(timeIntervalSinceReferenceDate: 816_000_000),
            bookmark: Data(Files.bios.path.utf8)
        )
        #expect(storage.kept == record, "kept with its bookmark, dated to the whole second")
        #expect(check.kept == record)
        #expect(await session.controls == [.powerOn(bytes: 524_288, exe: false), .stop], "the check's console is released")
        let job = check.job
        #expect(steps(check).map(\.state) == [.done, .done, .done, .done, .done])
        #expect(steps(check)[3].detail == "60 of 60 frames")
        #expect(job?.summary == JobPresentation.Summary("Your BIOS works: it reached its shell.", tone: .ok))
        #expect(job?.output == nil)
        #expect(job?.progress == nil)
        #expect(job?.actions == [JobPresentation.Action("Continue", role: .finish)])
        #expect(handedOn.isEmpty, "the pane takes the BIOS when the person continues")
        check.perform(JobPresentation.Action("Continue", role: .finish))
        #expect(handedOn == [record])
        #expect(check.job == nil)
        #expect(check.state == .idle)
    }

    @Test func aShellReachedBefore60FramesWaitsForThe60() async {
        let check = await following(Files.bios)
        await session.run(to: 30, reachedShell: true)
        #expect(await eventually { check.frame == 30 })
        #expect(check.state == .running(.frames))
        #expect(storage.kept == nil)
        await session.run(to: 60, reachedShell: true)
        #expect(await eventually { check.state == .done })
        #expect(storage.kept?.fileName == "my-console-bios.bin")
    }

    @Test func closingTheDoneSheetContinues() async {
        var handedOn = 0
        let check = await following(Files.bios) { _ in handedOn += 1 }
        await session.run(to: 60, reachedShell: true)
        #expect(await eventually { check.state == .done })
        check.close()
        #expect(check.state == .done, "Close isn't a done sheet's button")
        check.dismiss()
        #expect(handedOn == 1)
        #expect(check.job == nil)
    }

    @Test func choosingAgainFromTheDoneSheetStillHandsTheKeptBIOSOn() async {
        var handedOn: [BIOSRecord] = []
        let check = await following(Files.bios) { handedOn.append($0) }
        await session.run(to: 60, reachedShell: true)
        #expect(await eventually { check.state == .done })
        #expect(storage.kept != nil, "the library keeps it at done")
        check.chooseFile()
        #expect(handedOn.map(\.fileName) == ["my-console-bios.bin"], "the BIOS the library keeps reaches the pane")
        #expect(check.state == .idle)
        #expect(check.isChoosingFile)
    }

    // MARK: - No shell in 600 frames

    @Test func aBIOSThatNeverReachesItsShellIsRefusedAtFrame600AndNotKept() async {
        let check = await following(Files.copy)
        await session.run(to: 60)
        #expect(await eventually { check.state == .running(.shell) })
        await session.run(to: 599)
        #expect(await eventually { check.frame == 599 })
        #expect(check.state == .running(.shell), "still waiting for the shell at frame 599")
        await session.run(to: 600)
        #expect(await eventually { check.state == .failed(.shell, .noShell) })
        #expect(await settled(check))
        let job = check.job
        #expect(job?.subtitle == "bios-copy.bin")
        #expect(steps(check).map(\.state) == [.done, .done, .done, .done, .failed])
        #expect(steps(check)[3].detail == "60 of 60 frames")
        #expect(job?.summary == JobPresentation.Summary(
            "Your BIOS powered on but didn’t reach its shell in 600 frames. Choose another file.", tone: .danger
        ))
        #expect(job?.output == "PS1Console.reachedShell stayed false: the shell (0x80030000) wasn’t reached by frame 600")
        #expect(job?.actions == [JobPresentation.Action("Cancel", role: .close), JobPresentation.Action("Choose Another File…", role: .retry)])
        #expect(storage.kept == nil)
        #expect(!storage.calls.contains(.keep), "nothing is written")
        #expect(check.kept == nil)
        #expect(await session.controls == [.powerOn(bytes: 524_288, exe: false), .stop], "the check's console is released")
    }

    @Test func aLateFirstSnapshotPastFrame600IsStillRefused() async {
        let check = await following(Files.copy)
        await session.run(to: 640)
        #expect(await eventually { check.state == .failed(.shell, .noShell) })
        #expect(storage.kept == nil)
    }

    // MARK: - Wrong size

    @Test func aFileOfAnotherSizeIsRefusedWithItsSizeAndTheErrorUnderDetails() async {
        let check = makeCheck()
        check.check(Files.backup)
        #expect(await settled(check))
        let refusal = "PS1Console.powerOn(bios:) threw PS1Error.biosSize(271384)"
        #expect(check.state == .failed(.size, .wrongSize(bytes: 271_384, details: refusal)))
        let job = check.job
        #expect(job?.subtitle == "bios-backup.zip")
        #expect(steps(check) == [
            JobPresentation.Step("Read the file", detail: "271,384 bytes", state: .done),
            JobPresentation.Step("Check its size", detail: "A PS1 BIOS is 524,288 bytes (512 KB)", state: .failed),
            JobPresentation.Step("Work out its fingerprint", state: .pending),
            JobPresentation.Step("Power on and run 60 frames", state: .pending),
            JobPresentation.Step("Reach the BIOS’s shell", state: .pending),
        ])
        #expect(job?.summary == JobPresentation.Summary(
            "This file is 271,384 bytes. A PS1 BIOS is exactly 524,288 bytes. Choose the BIOS file itself.", tone: .danger
        ))
        #expect(job?.output == refusal)
        #expect(job?.actions == [JobPresentation.Action("Cancel", role: .close), JobPresentation.Action("Choose Another File…", role: .retry)])
        #expect(storage.reads(of: Files.backup) == 0, "a file of the wrong size is never read whole")
        #expect(await session.calls.isEmpty, "nothing powers on")
        #expect(storage.kept == nil)
    }

    @Test func theWrongSizeDetailsNameWhatPoweringOnThrows() async {
        // The refusal comes before the file is read, so its Details are the error the console's own
        // size check throws for that size: the real session's, here.
        let session = ConsoleSession<ContinuousClock>()
        do throws(PS1Error) {
            try await session.powerOn(bios: [UInt8](repeating: 0, count: 271_384), exe: nil)
            Issue.record("a 271,384-byte BIOS powered on")
        } catch {
            #expect(error == .biosSize(271_384))
            #expect(BIOSText.threw("PS1Console.powerOn(bios:)", error) == BIOSCheckViewModel.powerOnRefusal(271_384))
        }
        #expect(await session.snapshot.state == .poweredOff)
    }

    // MARK: - Stop

    @Test func stopEndsTheCheckAndKeepsNothing() async {
        let check = await following(Files.bios)
        await session.run(to: 24)
        #expect(await eventually { check.frame == 24 })
        check.stop()
        #expect(check.state == .stopped(.frames))
        #expect(await settled(check))
        #expect(await session.controls == [.powerOn(bytes: 524_288, exe: false), .stop])
        let job = check.job
        #expect(steps(check).map(\.state) == [.done, .done, .done, .stopped, .pending])
        #expect(steps(check)[3].detail == "24 of 60 frames")
        #expect(job?.progress == nil)
        #expect(job?.summary == JobPresentation.Summary("Stopped. iStation didn’t keep this BIOS.", tone: .warning))
        #expect(job?.output == nil)
        #expect(job?.actions == [JobPresentation.Action("Close", role: .close), JobPresentation.Action("Check Again", role: .retry)])
        // The shell reached after the stop changes nothing.
        await session.run(to: 80, reachedShell: true)
        #expect(await settled(check))
        #expect(check.state == .stopped(.frames))
        #expect(storage.kept == nil)
        #expect(!storage.calls.contains(.keep))
    }

    @Test func stopWhileLookingForTheShellKeepsNothing() async {
        let check = await following(Files.bios)
        await session.run(to: 90)
        #expect(await eventually { check.state == .running(.shell) })
        check.perform(JobPresentation.Action("Stop", role: .stop))
        #expect(check.state == .stopped(.shell))
        #expect(await settled(check))
        #expect(await session.controls == [.powerOn(bytes: 524_288, exe: false), .stop])
        #expect(storage.kept == nil)
    }

    @Test func checkAgainAfterAStopStartsAfresh() async {
        let check = await following(Files.bios)
        await session.run(to: 24)
        #expect(await eventually { check.frame == 24 })
        check.stop()
        check.perform(JobPresentation.Action("Check Again", role: .retry))
        #expect(check.isChoosingFile)
        #expect(check.job == nil)
        check.check(Files.copy)
        #expect(check.state == .running(.read))
        #expect(check.frame == 0)
        #expect(check.sha1 == nil)
        #expect(await eventually { check.state == .running(.frames) })
        #expect(await followed(session))
        #expect(await session.controls == [.powerOn(bytes: 524_288, exe: false), .stop, .powerOn(bytes: 524_288, exe: false)],
                "the first check's stop reaches the session before the second powers on")
        #expect(check.job?.subtitle == "bios-copy.bin")
        await session.run(to: 60, reachedShell: true)
        #expect(await eventually { check.state == .done })
        #expect(storage.kept?.fileName == "bios-copy.bin")
    }

    @Test func stopBeforeThePowerOnPowersNothingOnAndKeepsNothing() async {
        let check = makeCheck()
        check.check(Files.bios)
        check.stop()
        #expect(check.state == .stopped(.read))
        #expect(await settled(check))
        #expect(check.state == .stopped(.read))
        #expect(await session.calls.isEmpty)
        #expect(storage.kept == nil)
    }

    @Test func stopWhileTheFileIsReadPowersNothingOnAndStaysStopped() async {
        let gated = GatedStorage(storage)
        let check = BIOSCheckViewModel(session: session, storage: gated, now: { checkTime })
        check.check(Files.bios)
        #expect(await eventually { gated.waitingReads == 1 }, "the file is never read")
        check.stop()
        gated.letGo()
        #expect(await settled(check))
        #expect(check.state == .stopped(.read), "a read that ends after the Stop changes nothing")
        #expect(check.sha1 == nil)
        #expect(await session.calls.isEmpty)
        #expect(storage.kept == nil)
    }

    @Test func stopWhilePoweringOnLeavesTheSessionStopped() async {
        await session.holdPowerOns()
        let check = makeCheck()
        check.check(Files.bios)
        #expect(await holding(1, session), "the check never powered on")
        #expect(check.state == .running(.frames))
        check.stop()
        #expect(check.state == .stopped(.frames))
        // The Stop reaches the session before the power-on ends, so the check stops it again after.
        #expect(await controls(of: session) { $0.contains(.stop) })
        await session.letGo()
        #expect(await settled(check))
        #expect(await session.snapshot.state == .stopped, "the console powered on after the Stop is released")
        #expect(await !session.isFollowed)
        #expect(check.state == .stopped(.frames))
        #expect(storage.kept == nil)
    }

    @Test func stopWhileTheConsoleIsReleasedKeepsNothing() async {
        let check = await following(Files.bios)
        await session.holdStops()
        await session.run(to: 60, reachedShell: true)
        #expect(await holding(1, session), "the check never released its console")
        #expect(check.state == .running(.shell))
        check.stop()
        #expect(check.state == .stopped(.shell))
        #expect(await holding(2, session))
        await session.letGo()
        #expect(await settled(check))
        #expect(check.state == .stopped(.shell))
        #expect(check.kept == nil)
        #expect(storage.kept == nil)
        #expect(!storage.calls.contains(.keep), "a BIOS stopped while its console is released is never written")
    }

    @Test func aCheckAfterAStopWaitsForThatStopToReachTheSession() async {
        let check = await following(Files.bios)
        await session.holdStops()
        check.stop()
        #expect(await holding(1, session))
        check.check(Files.copy)
        #expect(check.state == .running(.read))
        try? await Task.sleep(for: .milliseconds(50))
        #expect(!storage.calls.contains(.bookmark(Files.copy.path)), "the second check starts once the first's stop has reached the session")
        #expect(await session.controls == [.powerOn(bytes: 524_288, exe: false), .stop])
        await session.letGo()
        #expect(await controls(of: session) { $0.count == 3 })
        #expect(await session.controls == [.powerOn(bytes: 524_288, exe: false), .stop, .powerOn(bytes: 524_288, exe: false)])
        #expect(await followed(session))
        await session.run(to: 60, reachedShell: true)
        #expect(await eventually { check.state == .done }, "the first check's stop never stopped the second's console")
        #expect(storage.kept?.fileName == "bios-copy.bin")
    }

    // MARK: - Files that can't be read or kept

    @Test func aFileThatCantBeReadIsRefused() async {
        storage.fail(FakeStorage.Failures(bytes: .cannotRead(path: Files.bios.path, reason: "Permission denied.")))
        let check = makeCheck()
        check.check(Files.bios)
        #expect(await settled(check))
        let details = #"KeptFile.bytes(at:) threw KeptFileError.cannotRead(path: "/Users/you/Documents/Console/my-console-bios.bin", reason: "Permission denied.")"#
        #expect(check.state == .failed(.read, .unreadable(details: details)))
        #expect(steps(check).map(\.state) == [.failed, .pending, .pending, .pending, .pending])
        #expect(steps(check)[0].detail == "524,288 bytes")
        #expect(check.job?.summary == JobPresentation.Summary("The BIOS couldn’t be read. Choose another file.", tone: .danger))
        #expect(check.job?.output == details)
        #expect(check.job?.actions == [JobPresentation.Action("Cancel", role: .close), JobPresentation.Action("Choose Another File…", role: .retry)])
        #expect(await session.calls.isEmpty)
    }

    @Test func aFileThatCantBeBookmarkedIsRefusedUnsized() async {
        let check = makeCheck()
        check.check(URL(fileURLWithPath: "/Users/you/Documents/gone.bin"))
        #expect(await settled(check))
        guard case .failed(.read, .unreadable(let details)) = check.state else {
            Issue.record("refused as \(check.state)")
            return
        }
        #expect(details.hasPrefix("KeptFile.bookmark(for:) threw KeptFileError.cannotBookmark("))
        #expect(steps(check)[0].detail == nil, "its size is unknown")
    }

    @Test func aBIOSTheLibraryCantKeepIsRefused() async {
        storage.fail(FakeStorage.Failures(keep: .cannotWrite(path: "/Library/library.json", reason: "Read-only.")))
        let check = await following(Files.bios)
        await session.run(to: 60, reachedShell: true)
        #expect(await eventually { check.state != .running(.frames) && check.state != .running(.shell) })
        let details = #"LibraryStore.keepBIOS(_:) threw LibraryStoreError.cannotWrite(path: "/Library/library.json", reason: "Read-only.")"#
        #expect(check.state == .failed(.shell, .notKept(details: details)))
        #expect(check.job?.summary == JobPresentation.Summary("Your BIOS reached its shell, but iStation couldn’t keep it. Choose the file again.", tone: .danger))
        #expect(check.job?.output == details)
        #expect(check.kept == nil)
        #expect(storage.kept == nil)
        #expect(await session.controls == [.powerOn(bytes: 524_288, exe: false), .stop])
    }

    // MARK: - The sheet's buttons

    @Test func aRefusalsButtonsCloseOrChooseAgain() async {
        let check = makeCheck()
        check.check(Files.backup)
        #expect(await settled(check))
        check.perform(JobPresentation.Action("Choose Another File…", role: .retry))
        #expect(check.job == nil)
        #expect(check.isChoosingFile)
        check.isChoosingFile = false
        check.check(Files.backup)
        #expect(await settled(check))
        check.perform(JobPresentation.Action("Cancel", role: .close))
        #expect(check.job == nil)
        #expect(!check.isChoosingFile)
        check.check(Files.backup)
        #expect(await settled(check))
        check.dismiss()
        #expect(check.job == nil)
    }

    @Test func nothingElseStartsWhileACheckRuns() async {
        let check = await following(Files.bios)
        #expect(!check.canChooseFile)
        check.chooseFile()
        #expect(!check.isChoosingFile)
        check.check(Files.copy)
        #expect(check.job?.subtitle == "my-console-bios.bin")
        check.close()
        check.finish()
        #expect(check.state == .running(.frames))
        check.dismiss()
        #expect(check.state == .stopped(.frames), "a running check's sheet closed without a button stops it")
        #expect(await settled(check))
        #expect(await session.controls == [.powerOn(bytes: 524_288, exe: false), .stop])
    }

    @Test func nothingBehindTheSheetOpensTheChooser() async {
        let check = makeCheck()
        #expect(check.canChooseFile)
        #expect(!check.isShowingJob)
        check.check(Files.backup)
        #expect(check.isShowingJob)
        #expect(await settled(check))
        #expect(check.isShowingJob)
        #expect(!check.canChooseFile, "Welcome's button and ⌘O do nothing under a refusal's sheet")
        check.perform(JobPresentation.Action("Choose Another File…", role: .retry))
        #expect(check.isChoosingFile, "the sheet's own button chooses again")
        #expect(!check.isShowingJob)
        #expect(check.canChooseFile)
    }
}
