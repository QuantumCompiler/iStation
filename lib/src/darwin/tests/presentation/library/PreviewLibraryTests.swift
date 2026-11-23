// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

#if DEBUG
import DataLibrary
import Foundation
@testable import PresentationLibrary
import Testing

/// The library's previews draw the design's Today level: the scan done adds every backup, as the Today scan
/// does (the design's "today" flow in `tools/check.mjs`), and the missing file's Details are the reason the
/// design records (`html/main.html`), both read by their repository paths, read-only. The previews are
/// reached through their own `PreviewLibrary` states, in memory.
@MainActor
@Suite struct PreviewLibraryTests {
    /// The design folder, located from this file (lib/src/darwin/tests/presentation/library/PreviewLibraryTests.swift).
    static let design = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("documentation/design/darwin")

    @Test func theScanDonePreviewTalliesAsTheTodayScanDoes() async throws {
        let library = PreviewLibrary.scanDone()
        #expect(await eventually { library.scan.state == .done })
        let tally = try #require(library.scan.job?.summary?.text)
        #expect(tally == "Added 7 games. 2 already in your library.")
        let flows = try String(contentsOf: Self.design.appendingPathComponent("tools/check.mjs"), encoding: .utf8)
        #expect(flows.contains("'\(tally)'"), "the design's today flow tallies its scan the same")
        #expect(library.games.count == 9)
    }

    @Test func aScanPreviewHeldOnItsFifthFileHoldsNoThread() async {
        // More scans held where the Scanning preview holds one than Swift's pool has threads: were each
        // held on a thread, as a blocking wait holds one, nothing else would run beside them.
        // Five seconds of patience rather than two: the other suites' fakes hold the pool's threads for
        // moments of their own while they run beside this one.
        let held = (0...ProcessInfo.processInfo.activeProcessorCount).map { _ in PreviewLibrary.scanRunning() }
        #expect(await within(.seconds(5)) { held.allSatisfy { $0.scan.results.count == 4 } }, "each reads its fifth file, gpu-test.exe")
        #expect(held.allSatisfy { $0.scan.job?.progress?.text == "Reading 5 of 9 · Homebrew/gpu-test.exe" })
        let ran = Ran()
        Task.detached { await MainActor.run { ran.isSet = true } }
        #expect(await within(.seconds(5)) { ran.isSet }, "a task still runs beside them")
    }

    @Test func aScanPreviewStoppedOnItsHeldFileEnds() async {
        // The held record hears its scan stop, so the scan ends rather than waiting at the gate for as long
        // as the preview lasts.
        let library = PreviewLibrary.scanRunning()
        #expect(await within(.seconds(5)) { library.scan.results.count == 4 })
        library.scan.stop()
        #expect(await settled(library.scan), "the scan ended where it was stopped")
        #expect(library.scan.results.count == 4, "the held file isn't added")
    }

    /// Waits on the main actor until `condition` holds, for up to `patience`: true once it holds.
    func within(_ patience: Duration, _ condition: () -> Bool) async -> Bool {
        let deadline = ContinuousClock.now.advanced(by: patience)
        while !condition() {
            guard ContinuousClock.now < deadline else { return false }
            try? await Task.sleep(for: .milliseconds(5))
        }
        return true
    }

    @Test func theMissingFilePreviewGivesTheReasonTheDesignRecords() async throws {
        let library = PreviewLibrary.locateOrRemove()
        #expect(await eventually { library.alert != nil })
        let details = try #require(library.alert?.details)
        #expect(details == #"KeptFile.resolve(_:) threw KeptFileError.cannotResolve(reason: "The file doesn’t exist.")"#)
        let prototype = try String(contentsOf: Self.design.appendingPathComponent("html/main.html"), encoding: .utf8)
        #expect(prototype.contains(details))
    }
}
#endif
