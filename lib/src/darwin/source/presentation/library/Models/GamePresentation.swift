// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import DataLibrary
import PresentationStyles

/// One game as the library's table row and grid tile show it (boards `Mac-TodayLibrary`,
/// `Mac-LibraryGrid`), every word worked out by `LibraryViewModel` at the Today level: a disc's console and
/// serial "Unknown", a PS-EXE's "PS1" and "None". The view lays it out and maps `Emphasis` and `Tone` to
/// the styles' colors and fonts.
public struct GameRow: Sendable, Equatable, Identifiable {
    /// How a cell's words are drawn.
    public enum Emphasis: Sendable, Equatable {
        /// In the text's own color.
        case plain
        /// Quieter, for what isn't known or isn't there: "Unknown", "None", "Never".
        case muted
    }

    /// The game's id in the library.
    public var id: GameRecord.ID
    /// Its name as the library shows it: "Harbor Lights (USA)".
    public var name: String
    /// The SF Symbol beside the name: a disc, or a program for a PS-EXE.
    public var symbol: String
    /// The Console column: "PS1" for a PS-EXE, "Unknown" for a disc until 5h reads it.
    public var console: String
    /// How the console is drawn: muted while unknown.
    public var consoleEmphasis: Emphasis
    /// The Serial column, in the monospaced face: "None" for a PS-EXE, "Unknown" for a disc.
    public var serial: String
    /// How the serial is drawn: muted unless one is known.
    public var serialEmphasis: Emphasis
    /// The Format column, muted: ".cue", ".iso", ".m3u", "PS-EXE".
    public var format: String
    /// The Size column, muted, in tabular figures: "512 MB"; "Unknown" for a file that can't be found.
    public var size: String
    /// The Last played column, muted: "Today, 9:41", "Never".
    public var lastPlayed: String
    /// The chip beside the name: "File missing" for a file that can't be found; nil for none.
    public var flag: String?
    /// The chip's tone: warning for a missing file.
    public var flagTone: Tone?
    /// What VoiceOver says for the row: "gpu-test, PS1", "Lantern Street, Unknown, File missing".
    public var accessibilityLabel: String
    /// The two letters the grid tile draws in place of artwork: "HL".
    public var initials: String
    /// The tile's console chip: "PS1", or "?" while unknown.
    public var consoleBadge: String
    /// The tile's corner caption, monospaced: a known serial, "PS-EXE" for a program, "" for a disc.
    public var serialBadge: String
    /// The line under the tile's name: its flag, else "Played Today, 9:41" or "Never played".
    public var tileCaption: String
}

/// The selected game as Game info shows it (boards `Mac-TodayLibrary`, `Mac-LibraryInspector`,
/// `Mac-LibraryMissing`): its facts at the Today level, the note on a missing file, and its buttons.
public struct GameInfo: Sendable, Equatable {
    /// One line of facts: its name on the left, its value on the right.
    public struct Fact: Sendable, Equatable {
        /// How a value is drawn.
        public enum Style: Sendable, Equatable {
            /// In the text's own face and color.
            case plain
            /// Quieter: a console not read yet.
            case muted
            /// In the monospaced face: a serial, a file's name, a folder.
            case monospaced
        }

        /// The fact's name: "Console".
        public var name: String
        /// Its value: "Unknown until discs can be read".
        public var value: String
        /// How the value is drawn.
        public var style: Style

        /// A fact named `name`, worth `value`, drawn as `style`.
        public init(_ name: String, _ value: String, style: Style = .plain) {
            self.name = name
            self.value = value
            self.style = style
        }
    }

    /// What Game info's first button does.
    public enum Action: Sendable, Equatable {
        /// Play: opens the game.
        case play
        /// Locate…: opens the chooser to find a missing file.
        case locate
    }

    /// The game's id in the library.
    public var id: GameRecord.ID
    /// Its name, the heading, beside Rename.
    public var name: String
    /// The two letters drawn in place of artwork.
    public var initials: String
    /// What the library knows of it, in order: Console, Serial, Format, Size, File, Folder, Added, Last played.
    public var facts: [Fact]
    /// The note above the facts, for a file that can't be found; nil for none.
    public var banner: String?
    /// The note's tone.
    public var bannerTone: Tone?
    /// What the first button does: Play, or Locate… for a missing file.
    public var action: Action
    /// The first button's title: "Play" or "Locate…".
    public var actionTitle: String
    /// Its tooltip: "Play (↩)", "Find the file".
    public var actionHelp: String
    /// Whether it can be pressed: Play only for a recognized PS-EXE whose file is there; Locate… always.
    public var isActionEnabled: Bool
    /// Why Play is off, under it: "Discs play from v0.2.0."; nil when it's on, and for Locate….
    public var reason: String?
    /// Whether Show in Finder applies: not for a file that can't be found.
    public var canShowInFinder: Bool
}
