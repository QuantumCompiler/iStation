// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import BusinessPS1
import DataLibrary
import Foundation
@testable import PresentationBIOS
import Testing

/// The first run's words are the design's own: every sentence Welcome, the pane and the check show is in
/// the prototype (`html/main.html`) as it is written, read here by its repository path, read-only.
@Suite struct BIOSTextTests {
    /// html/main.html, located from this file (lib/src/darwin/tests/presentation/bios/BIOSTextTests.swift).
    static let prototype = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("documentation/design/darwin/html/main.html")

    @Test func welcomeSaysWhatABIOSIsAndGivesOneSentenceOfGuidance() {
        #expect(BIOSText.welcomeTitle == "Welcome to iStation")
        #expect(BIOSText.welcomeLead == "iStation plays PS1 games on your Mac. A BIOS is the small program built into a console that starts it up. iStation runs yours, so your games start the way they do on your console.")
        #expect(BIOSText.guidance == "It comes from your own console: iStation can’t provide one, and it expects a 512 KB file.")
        #expect(BIOSText.neverSendsAnything == "iStation never downloads a BIOS or games, and never sends anything off your Mac.")
        let words = [BIOSText.welcomeLead, BIOSText.guidance, BIOSText.paneNote].joined(separator: " ").lowercased()
        for named in ["http", "www.", ".com", "dump", "download it", "rip", "tool", "app store"] {
            #expect(!words.contains(named), "the guidance names no tool, method or link: \(named)")
        }
    }

    @Test func everySentenceIsTheDesignsOwn() throws {
        let design = try String(contentsOf: Self.prototype, encoding: .utf8)
        let sentences = [
            BIOSText.welcomeTitle, BIOSText.welcomeLead, BIOSText.guidance, BIOSText.chooseBIOSFile, BIOSText.chooseBIOSFileHelp,
            BIOSText.acknowledgements, BIOSText.neverSendsAnything,
            BIOSText.chooserMessage, "ok: '\(BIOSText.chooserConfirmation)'",
            BIOSText.keptByBookmark, BIOSText.paneNote, BIOSText.runTheBIOS, BIOSText.chooseAnotherBIOS, BIOSText.showInFinder,
            "Checking your BIOS", "Frames run", "A PS1 BIOS is 524,288 bytes (512 KB)",
            "Your BIOS works: it reached its shell.", "Stopped. iStation didn’t keep this BIOS.",
            "Your BIOS powered on but didn’t reach its shell in 600 frames. Choose another file.",
            "PS1Console.reachedShell stayed false: the shell (0x80030000) wasn’t reached by frame 600",
            " bytes. A PS1 BIOS is exactly 524,288 bytes. Choose the BIOS file itself.",
            "PS1Console.powerOn(bios:) threw PS1Error.biosSize(",
            "Choose Another File…", "Check Again", "'Continue'", "'Cancel'", "'Close'", "'Stop'",
            ": it reached its shell.", "In ",
        ] + BIOSCheckViewModel.Step.allCases.map(\.name)
        for sentence in sentences {
            #expect(design.contains(sentence), "html/main.html doesn't say \(sentence)")
        }
    }

    @Test func aFingerprintIsShownInGroupsOfFour() {
        #expect(BIOSText.fingerprint("3f9a1c0e52d488b0e7a14c269d0f51aa7b21c3e8") == "SHA-1 3f9a 1c0e 52d4 88b0 e7a1 4c26 9d0f 51aa 7b21 c3e8")
        #expect(BIOSText.fingerprint(Fingerprint.sha1(of: [UInt8]())) == "SHA-1 da39 a3ee 5e6b 4b0d 3255 bfef 9560 1890 afd8 0709")
    }

    @Test func sizesAreWrittenAsTheDesignWritesThem() {
        #expect(BIOSText.biosSize == 524_288)
        #expect(BIOSText.bytes(271_384) == "271,384 bytes")
        #expect(BIOSText.bytesAndKilobytes(524_288) == "524,288 bytes (512 KB)")
    }

    @Test func aFailedCallIsNamedWithWhatItThrew() {
        #expect(BIOSText.threw("PS1Console.powerOn(bios:)", PS1Error.biosSize(1_000)) == "PS1Console.powerOn(bios:) threw PS1Error.biosSize(1000)")
        #expect(BIOSText.threw("KeptFile.resolve(_:)", KeptFileError.cannotResolve(reason: "Gone.")) == #"KeptFile.resolve(_:) threw KeptFileError.cannotResolve(reason: "Gone.")"#)
        struct DiskFull: Error, CustomStringConvertible {
            var description: String { "the disk is full" }
        }
        #expect(BIOSText.threw("KeptFile.bytes(at:)", DiskFull()) == "KeptFile.bytes(at:) threw the disk is full", "an error that isn't an enum's case describes itself")
    }
}
