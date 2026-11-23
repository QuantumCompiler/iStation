// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import BusinessPS1
import PresentationStyles

/// The words the first run and the BIOS pane say, as the design's `html/main.html` has them (boards
/// `Mac-Welcome` and `Mac-BiosPane`), and the helpers both view-models write their figures with. The
/// copy is for someone who has never heard of a BIOS (decided 2026-11-22): what one is, and one
/// sentence of guidance that names no tool, method or link.
enum BIOSText {
    // MARK: What a BIOS is, on Welcome and the pane alike

    /// What a BIOS is and why iStation needs yours.
    static let whatABIOSIs = "A BIOS is the small program built into a console that starts it up. iStation runs yours, so your games start the way they do on your console."
    /// The one sentence of guidance: where the file comes from, that iStation can't provide one, and its size.
    static let guidance = "It comes from your own console: iStation can’t provide one, and it expects a 512 KB file."

    // MARK: Welcome

    /// Welcome's title.
    static let welcomeTitle = "Welcome to iStation"
    /// Welcome's first paragraph: what iStation does, then what a BIOS is.
    static let welcomeLead = "iStation plays PS1 games on your Mac. " + whatABIOSIs
    /// Welcome's button that opens the file chooser.
    static let chooseBIOSFile = "Choose BIOS File…"
    /// Its tooltip, naming its shortcut.
    static let chooseBIOSFileHelp = "Choose BIOS File (⌘O)"
    /// Welcome's button that opens the acknowledgements.
    static let acknowledgements = "Acknowledgements"
    /// Welcome's closing caption (contract row C47).
    static let neverSendsAnything = "iStation never downloads a BIOS or games, and never sends anything off your Mac."

    // MARK: The file chooser (Mac-BiosPicker)

    /// The chooser's message: how the chosen file is kept.
    static let chooserMessage = "iStation reads this file where it is and keeps a bookmark to it. It never copies it."
    /// The chooser's button that chooses the file.
    static let chooserConfirmation = "Choose"

    // MARK: The BIOS pane

    /// The pane's first note: how the file is kept.
    static let keptByBookmark = "iStation keeps a bookmark to this file and reads it each time the console starts. It never copies the file."
    /// The pane's second note: what a BIOS is, the guidance, and what changes with PS2 games.
    static let paneNote = whatABIOSIs + " " + guidance + " When PS2 games arrive, they won’t need a BIOS file."
    /// The pane's button that powers the player's console on with the kept BIOS.
    static let runTheBIOS = "Run the BIOS"
    /// The pane's button that checks another file in place of the kept one.
    static let chooseAnotherBIOS = "Choose Another BIOS…"
    /// The pane's button that shows the kept file in the Finder.
    static let showInFinder = "Show in Finder"

    // MARK: Figures

    /// A PS1 BIOS's size in bytes, as the console takes it: 524,288.
    static var biosSize: Int { PS1Bus.biosSize }

    /// `count` bytes, grouped as the design writes numbers: "524,288 bytes".
    static func bytes(_ count: Int) -> String {
        Figures.grouped(count) + " bytes"
    }

    /// A size with its kilobytes, as the design writes a BIOS's: "524,288 bytes (512 KB)".
    static func bytesAndKilobytes(_ count: Int) -> String {
        bytes(count) + " (\(Figures.grouped(count / 1024)) KB)"
    }

    /// A SHA-1 fingerprint as the design shows it, its digits in groups of four: "SHA-1 3f9a 1c0e …".
    static func fingerprint(_ sha1: String) -> String {
        var groups: [Substring] = []
        var rest = Substring(sha1)
        while !rest.isEmpty {
            groups.append(rest.prefix(4))
            rest = rest.dropFirst(4)
        }
        return (["SHA-1"] + groups).joined(separator: " ")
    }

    /// The exact call that failed and what it threw, for Details: "PS1Console.powerOn(bios:) threw
    /// PS1Error.biosSize(271384)" — `Details.threw(_:_:)`, which the library writes its Details with too.
    static func threw(_ call: String, _ error: any Error) -> String {
        Details.threw(call, error)
    }
}
