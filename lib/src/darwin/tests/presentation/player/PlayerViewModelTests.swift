// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import BusinessSession
@testable import PresentationPlayer
import Testing

/// The BIOS alone, as the design's placeholder names it: the BIOS check's run.
private let biosRun = PlayerRun(biosFileName: "my-console-bios.bin", biosSize: 524_288)
/// A PS-EXE from the library, booted after power-on.
private let programRun = PlayerRun(
    biosFileName: "my-console-bios.bin", biosSize: 524_288,
    program: PlayerRun.Program(name: "gpu-test", fileName: "gpu-test.exe")
)

/// A player following `session`, told it plays `run`, once its first snapshot has arrived.
@MainActor
private func playing(_ run: PlayerRun = biosRun, on session: FakeSession) async -> PlayerViewModel {
    let player = PlayerViewModel(session: session)
    player.started(run)
    _ = await eventually { player.state != .nothingLoaded }
    return player
}

@MainActor
@Suite struct PlayerViewModelTests {
    // MARK: - Nothing loaded

    @Test func aNewPlayerHasNothingLoaded() async {
        let session = FakeSession()
        let player = PlayerViewModel(session: session)
        #expect(player.state == .nothingLoaded)
        #expect(player.consoleName == "PS1")
        #expect(player.message == "Nothing to play yet.")
        #expect(player.run == nil)
        #expect(!player.isPlaying)
        #expect(player.statusLine == "")
        #expect(player.confirmation == nil)
        #expect(!player.isFullScreen)
        #expect(await session.calls.isEmpty, "a player follows nothing until a run starts")
    }

    @Test func withNothingLoadedNoControlApplies() async {
        let session = FakeSession()
        let player = PlayerViewModel(session: session)
        #expect(!player.canPause && !player.canResume && !player.canTogglePause)
        #expect(!player.canReset && !player.canStop && !player.canToggleFullScreen)
        player.pause()
        player.resume()
        player.togglePause()
        player.askToReset()
        player.askToStop()
        player.toggleFullScreen()
        await player.settled()
        #expect(player.confirmation == nil)
        #expect(!player.isFullScreen)
        #expect(await session.calls.isEmpty)
    }

    @Test func aRunToldBeforePowerOnShowsNothingLoadedUntilItRuns() async {
        let session = FakeSession(ConsoleSessionSnapshot(state: .poweredOff))
        let player = PlayerViewModel(session: session)
        player.started(biosRun)
        #expect(player.state == .nothingLoaded)
        #expect(player.message == "Nothing to play yet.")
        await session.send(ConsoleSessionSnapshot(state: .running))
        #expect(await eventually { player.state == .running })
    }

    // MARK: - Running

    @Test func aStartedRunFollowsTheSessionFromFrameZero() async {
        let session = FakeSession()
        let player = await playing(on: session)
        #expect(player.state == .running)
        #expect(player.run == biosRun)
        #expect(player.isPlaying)
        #expect(player.frame == 0)
        #expect(player.name == "BIOS")
        #expect(player.statusText == "Running")
        #expect(player.frameText == "0")
        #expect(player.hudFrameText == "Frame 0")
        #expect(player.message == "This build runs the console but can’t show its picture yet.")
        #expect(!player.showsPausedOverlay)
        #expect(await session.calls == [.snapshots])
    }

    @Test func untilASecondHasRunTheFramesPerSecondAreNotShown() async {
        let session = FakeSession()
        let player = await playing(on: session)
        await session.send(ConsoleSessionSnapshot(state: .running, frame: 12))
        #expect(await eventually { player.frame == 12 })
        #expect(player.framesPerSecondText == nil)
        #expect(player.framesRunCaption == "frames run")
        #expect(player.statusLine == "Running · frame 12")
    }

    @Test func theFramesAndFramesPerSecondFollowTheSnapshots() async {
        let session = FakeSession()
        let player = await playing(on: session)
        await session.send(ConsoleSessionSnapshot(state: .running, frame: 1_234, framesPerSecond: 59.94))
        #expect(await eventually { player.frame == 1_234 })
        #expect(player.framesPerSecond == 59.94)
        #expect(player.frameText == "1,234")
        #expect(player.hudFrameText == "Frame 1,234")
        #expect(player.framesPerSecondText == "60 per second")
        #expect(player.framesRunCaption == "frames run · 60 per second")
        #expect(player.statusLine == "Running · frame 1,234 · 60 frames a second")
    }

    @Test func framesPerSecondShowAsTheSessionMeasuresThem() async {
        let session = FakeSession()
        let player = await playing(on: session)
        await session.send(ConsoleSessionSnapshot(state: .running, frame: 18_342, framesPerSecond: 37.6))
        #expect(await eventually { player.frame == 18_342 })
        #expect(player.framesPerSecondText == "38 per second", "the personal build's debug build runs slower than 60, and says so")
        #expect(player.statusLine == "Running · frame 18,342 · 38 frames a second")
    }

    @Test func aPSEXEIsNamedAsTheLibraryNamesIt() async {
        let player = await playing(programRun, on: FakeSession())
        #expect(player.name == "gpu-test")
    }

    // MARK: - Pause and resume

    @Test func pausingHoldsTheFrame() async {
        let session = FakeSession(ConsoleSessionSnapshot(state: .running, frame: 1_234, framesPerSecond: 60))
        let player = await playing(on: session)
        #expect(player.canPause && !player.canResume && player.canTogglePause)
        #expect(player.pauseTitle == "Pause")
        player.pause()
        #expect(await eventually { player.state == .paused })
        #expect(await session.controls == [.pause])
        #expect(player.frame == 1_234)
        #expect(player.statusText == "Paused")
        #expect(player.framesPerSecondText == "paused")
        #expect(player.framesRunCaption == "frames run · paused")
        #expect(player.statusLine == "Paused · frame 1,234")
        #expect(player.showsPausedOverlay)
        #expect(!player.canPause && player.canResume && player.canTogglePause)
        #expect(player.pauseTitle == "Resume")
    }

    @Test func resumingRunsFromTheHeldFrame() async {
        let session = FakeSession(ConsoleSessionSnapshot(state: .paused, frame: 1_234))
        let player = await playing(on: session)
        #expect(player.state == .paused)
        player.resume()
        #expect(await eventually { player.state == .running })
        #expect(await session.controls == [.resume])
        #expect(player.frame == 1_234)
        #expect(!player.showsPausedOverlay)
    }

    @Test func togglePauseGoesBothWays() async {
        let session = FakeSession()
        let player = await playing(on: session)
        player.togglePause()
        #expect(await eventually { player.state == .paused })
        player.togglePause()
        #expect(await eventually { player.state == .running })
        #expect(await session.controls == [.pause, .resume])
    }

    @Test func pauseAndResumeActOnlyInTheirStates() async {
        let session = FakeSession()
        let player = await playing(on: session)
        player.resume()
        await player.settled()
        #expect(await session.controls.isEmpty, "a running player has nothing to resume")
        player.pause()
        #expect(await eventually { player.state == .paused })
        player.pause()
        await player.settled()
        #expect(await session.controls == [.pause], "a paused player has nothing to pause")
    }

    @Test func controlsReachTheSessionInTheOrderGiven() async {
        let session = FakeSession(ConsoleSessionSnapshot(state: .running, frame: 1_234), pauseTakes: .milliseconds(20))
        let player = await playing(on: session)
        player.askToReset()
        player.confirm()
        await player.settled()
        #expect(await session.controls == [.pause, .reset], "the alert's pause finishes before the reset is sent")
        #expect(await eventually { player.state == .running && player.frame == 0 })
        #expect(await session.current.state == .running, "a reset overtaken by its pause would leave frame 0 paused")
    }

    // MARK: - Reset

    @Test func resetAsksFirstAndPausesTheGame() async {
        let session = FakeSession(ConsoleSessionSnapshot(state: .running, frame: 1_234, framesPerSecond: 60))
        let player = await playing(on: session)
        #expect(player.canReset)
        player.askToReset()
        #expect(player.confirmation == .reset)
        #expect(await eventually { player.state == .paused }, "the design pauses while the alert asks")
        #expect(await session.controls == [.pause])
        #expect(!player.showsPausedOverlay, "the alert stands in for the paused overlay")
        #expect(!player.canTogglePause && !player.canReset && !player.canStop && !player.canToggleFullScreen)
    }

    @Test func resetsDetailsNameTheBIOSAndItsSize() async {
        let player = await playing(on: FakeSession())
        player.askToReset()
        #expect(player.alert == PlayerAlert(
            title: "Reset the console?",
            message: "The game starts again from the beginning. Anything you haven’t saved is lost.",
            details: "PS1Console.powerOn(bios:) with my-console-bios.bin (524,288 bytes)",
            confirmTitle: "Reset"
        ))
    }

    @Test func resetsDetailsBootThePSEXEAgain() async {
        let player = await playing(programRun, on: FakeSession())
        player.askToReset()
        #expect(player.alert == PlayerAlert(
            title: "Reset the console?",
            message: "The program starts again from the beginning. Anything you haven’t saved is lost.",
            details: "PS1Console.powerOn(bios:) with my-console-bios.bin (524,288 bytes)\nthen boot(exe:) with gpu-test.exe",
            confirmTitle: "Reset"
        ))
    }

    @Test func confirmingResetRunsFromFrameZero() async {
        let session = FakeSession(ConsoleSessionSnapshot(state: .running, frame: 1_234, framesPerSecond: 60))
        let player = await playing(on: session)
        player.askToReset()
        #expect(await eventually { player.state == .paused })
        player.confirm()
        #expect(player.confirmation == nil)
        #expect(await eventually { player.state == .running && player.frame == 0 })
        #expect(await session.controls == [.pause, .reset])
    }

    @Test func cancellingResetLeavesTheGamePaused() async {
        let session = FakeSession(ConsoleSessionSnapshot(state: .running, frame: 1_234))
        let player = await playing(on: session)
        player.askToReset()
        #expect(await eventually { player.state == .paused })
        player.cancel()
        await player.settled()
        #expect(player.confirmation == nil)
        #expect(player.alert == nil)
        #expect(player.state == .paused)
        #expect(player.frame == 1_234)
        #expect(player.showsPausedOverlay)
        #expect(await session.controls == [.pause])
    }

    @Test func askingWhilePausedKeepsTheGamePaused() async {
        let session = FakeSession(ConsoleSessionSnapshot(state: .paused, frame: 5))
        let player = await playing(on: session)
        player.askToReset()
        await player.settled()
        #expect(player.confirmation == .reset)
        #expect(await session.controls == [.pause], "the pause goes anyway, and does nothing to a paused session")
        #expect(await session.current.state == .paused)
        #expect(await session.current.frame == 5)
    }

    @Test func askingWhileAResumeIsOnItsWayStillPausesTheGame() async {
        let session = FakeSession(ConsoleSessionSnapshot(state: .paused, frame: 5))
        let player = await playing(on: session)
        player.resume()
        player.askToReset() // before the resumed snapshot arrives: the player still shows paused
        await player.settled()
        #expect(player.confirmation == .reset)
        #expect(await session.controls == [.resume, .pause])
        #expect(await session.current.state == .paused, "the game must not run under the alert")
        #expect(await eventually { player.state == .paused })
    }

    @Test func oneConfirmationAtATime() async {
        let player = await playing(on: FakeSession())
        player.askToReset()
        player.askToStop()
        #expect(player.confirmation == .reset)
    }

    // MARK: - Stop

    @Test func stopAsksFirstForTheBIOS() async {
        let session = FakeSession()
        let player = await playing(on: session)
        #expect(player.canStop)
        player.askToStop()
        #expect(player.confirmation == .stop)
        #expect(player.alert == PlayerAlert(
            title: "Stop the BIOS?",
            message: "Anything you haven’t saved is lost.",
            details: "Ends the console’s run loop and releases it. The disc image and your BIOS aren’t changed.",
            confirmTitle: "Stop"
        ))
        #expect(await eventually { player.state == .paused })
    }

    @Test func stopAsksFirstForAPSEXE() async {
        let player = await playing(programRun, on: FakeSession())
        player.askToStop()
        #expect(player.alert?.title == "Stop playing gpu-test?")
        #expect(player.alert?.details == "Ends the console’s run loop and releases it. The disc image and your BIOS aren’t changed.")
    }

    @Test func confirmingStopEndsTheRunAndSavesNothing() async {
        let session = FakeSession(ConsoleSessionSnapshot(state: .running, frame: 1_234, framesPerSecond: 60))
        let player = await playing(on: session)
        player.askToStop()
        #expect(await eventually { player.state == .paused })
        player.confirm()
        #expect(await eventually { player.state == .stopped })
        #expect(await session.controls == [.pause, .stop], "stop saves nothing: the session's stop is the only call")
        #expect(player.confirmation == nil)
        #expect(!player.isPlaying)
        #expect(player.message == "Stopped. Nothing is running.")
        #expect(player.statusLine == "")
        #expect(!player.canTogglePause && !player.canReset && !player.canStop && !player.canToggleFullScreen)
    }

    @Test func cancellingStopKeepsTheRun() async {
        let session = FakeSession()
        let player = await playing(on: session)
        player.askToStop()
        #expect(await eventually { player.state == .paused })
        player.cancel()
        await player.settled()
        #expect(player.state == .paused)
        #expect(await session.controls == [.pause])
    }

    @Test func aSessionStoppedElsewhereStopsThePlayer() async {
        let session = FakeSession()
        let player = await playing(on: session)
        player.askToReset()
        await session.stop()
        #expect(await eventually { player.state == .stopped })
        #expect(player.confirmation == nil, "an alert about a run that ended asks nothing")
    }

    @Test func aRunStartedAfterAStopIsFollowed() async {
        let session = FakeSession()
        let player = await playing(on: session)
        player.askToStop()
        player.confirm()
        #expect(await eventually { player.state == .stopped })
        // The starter powers the session on again, then tells the player.
        await session.send(ConsoleSessionSnapshot(state: .running))
        player.started(programRun)
        #expect(await eventually { player.state == .running })
        #expect(player.run == programRun)
        #expect(player.name == "gpu-test")
        await session.send(ConsoleSessionSnapshot(state: .running, frame: 3))
        #expect(await eventually { player.frame == 3 })
    }

    @Test func aRunToldBeforeTheOldOneStopsIsFollowedOnceItPowersOn() async {
        // A starter replacing a run that plays may tell the player first, then stop the old run and
        // power the session on again: the stop finishes the stream the player follows.
        let session = FakeSession(ConsoleSessionSnapshot(state: .running, frame: 50))
        let player = await playing(on: session)
        player.started(programRun)
        try? await Task.sleep(for: .milliseconds(10))
        await session.stop()
        await session.send(ConsoleSessionSnapshot(state: .running, frame: 0))
        await session.send(ConsoleSessionSnapshot(state: .running, frame: 1))
        #expect(await eventually { player.state == .running && player.frame == 1 }, "the player follows the session's next stream after a stop")
        #expect(player.run == programRun)
        #expect(player.name == "gpu-test")
        await session.send(ConsoleSessionSnapshot(state: .running, frame: 2))
        #expect(await eventually { player.frame == 2 })
    }

    @Test func aPlayerStoppedFollowsTheNextPowerOn() async {
        let session = FakeSession()
        let player = await playing(on: session)
        player.askToStop()
        player.confirm()
        #expect(await eventually { player.state == .stopped })
        await session.send(ConsoleSessionSnapshot(state: .running, frame: 4))
        #expect(await eventually { player.state == .running && player.frame == 4 })
    }

    @Test func aPlayerLetGoLetsItsSessionGo() async {
        weak var weakSession: FakeSession?
        weak var weakPlayer: PlayerViewModel?
        do {
            let session = FakeSession(ConsoleSessionSnapshot(state: .paused, frame: 5))
            let player = await playing(on: session)
            #expect(player.state == .paused)
            weakSession = session
            weakPlayer = player
        }
        #expect(await eventually { weakPlayer == nil && weakSession == nil },
                "a paused session sends nothing that would end the follow, so letting the player go has to")
    }

    @Test func aStreamThatEndsLeavesThePlayerAsItWas() async {
        let session = FakeSession(ConsoleSessionSnapshot(state: .running, frame: 7))
        let player = await playing(on: session)
        await session.finishStreams()
        await session.send(ConsoleSessionSnapshot(state: .running, frame: 8))
        try? await Task.sleep(for: .milliseconds(20))
        #expect(player.frame == 7)
        #expect(player.state == .running)
    }

    // MARK: - Full screen

    @Test func fullScreenTogglesWhilePlaying() async {
        let player = await playing(on: FakeSession())
        #expect(player.canToggleFullScreen)
        #expect(player.fullScreenTitle == "Enter Full Screen")
        player.toggleFullScreen()
        #expect(player.isFullScreen)
        #expect(player.fullScreenTitle == "Exit Full Screen")
        player.toggleFullScreen()
        #expect(!player.isFullScreen)
        player.toggleFullScreen()
        player.exitFullScreen()
        #expect(!player.isFullScreen)
    }

    @Test func theWindowsOwnFullScreenIsFollowed() async {
        let player = await playing(on: FakeSession())
        player.fullScreenDidChange(true)
        #expect(player.isFullScreen)
        player.fullScreenDidChange(false)
        #expect(!player.isFullScreen)
    }

    @Test func stoppingLeavesFullScreen() async {
        let session = FakeSession()
        let player = await playing(on: session)
        player.toggleFullScreen()
        player.askToStop()
        player.confirm()
        #expect(await eventually { player.state == .stopped })
        #expect(!player.isFullScreen)
    }

    @Test func fullScreenCanBeLeftOnceNothingPlays() async {
        let player = PlayerViewModel(session: FakeSession())
        player.fullScreenDidChange(true)
        #expect(player.canToggleFullScreen, "a window the person made full screen can always leave it")
        player.toggleFullScreen()
        #expect(!player.isFullScreen)
        #expect(!player.canToggleFullScreen)
    }

    // MARK: - Numbers

    @Test func numbersAreGroupedByThousandsAsTheDesignWritesThem() {
        #expect(PlayerViewModel.grouped(0) == "0")
        #expect(PlayerViewModel.grouped(999) == "999")
        #expect(PlayerViewModel.grouped(1_000) == "1,000")
        #expect(PlayerViewModel.grouped(524_288) == "524,288")
        #expect(PlayerViewModel.grouped(1_048_576) == "1,048,576")
        #expect(PlayerViewModel.grouped(-12_345) == "-12,345")
    }

    @Test func resetsDetailsNameTheKeptFileNotThePlaceholder() async {
        let run = PlayerRun(biosFileName: "bios-backup.bin", biosSize: 524_288)
        let player = await playing(run, on: FakeSession())
        player.askToReset()
        #expect(player.alert?.details == "PS1Console.powerOn(bios:) with bios-backup.bin (524,288 bytes)")
    }

    // MARK: - The window

    @Test func theWindowIsTitledWithTheRunWhileItPlays() async {
        let session = FakeSession()
        #expect(PlayerViewModel(session: session).windowTitle == nil, "nothing plays: the window keeps the app's own title")
        let player = await playing(on: session)
        #expect(player.windowTitle == "BIOS")
        let program = await playing(programRun, on: FakeSession(ConsoleSessionSnapshot(state: .paused, frame: 3)))
        #expect(program.windowTitle == "gpu-test")
        player.askToStop()
        player.confirm()
        #expect(await eventually { player.state == .stopped })
        #expect(player.windowTitle == nil)
    }
}
