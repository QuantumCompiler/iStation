// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import DataLibrary
import UniformTypeIdentifiers

/// The kinds of file the library's choosers offer: the types the macOS app imports for a cue sheet, a disc
/// track, a disc playlist and a PS-EXE (its `Info.plist`'s `UTImportedTypeDeclarations`, under these
/// identifiers), and whatever the system already calls a file with one of the library's extensions — an
/// .iso is the system's own disc image, an .m3u its audio playlist and an .exe a Windows program — so a file
/// the system types its own way can still be chosen. An imported type yields to one the system or another
/// app declares for the same extension, as Uniform Type Identifiers have it: where the system knows .bin,
/// .m3u or .exe, `discTrack`, `discPlaylist` and `program` are the system's types. A type the system gives
/// an extension may carry others too (.m3u8, say), so the library still refuses a file chosen through it
/// whose extension isn't a game's.
public enum GameFileTypes {
    /// The imported types' identifiers, as `apps/macos/Info.plist` declares them: a cue sheet, a disc
    /// track, a disc playlist and a PS-EXE.
    static let cueSheetIdentifier = "local.istation.cue-sheet"
    static let discTrackIdentifier = "local.istation.disc-track"
    static let discPlaylistIdentifier = "local.istation.disc-playlist"
    static let programIdentifier = "local.istation.ps-exe"

    /// A cue sheet, .cue: the text that names a disc image's tracks.
    public static let cueSheet = UTType(importedAs: cueSheetIdentifier, conformingTo: .plainText)
    /// A disc image's track, .bin, which a cue sheet names; never chosen on its own.
    public static let discTrack = UTType(importedAs: discTrackIdentifier, conformingTo: .data)
    /// A playlist of a game's discs, .m3u.
    public static let discPlaylist = UTType(importedAs: discPlaylistIdentifier, conformingTo: .plainText)
    /// A PS-EXE program, .exe.
    public static let program = UTType(importedAs: programIdentifier, conformingTo: .data)

    /// Every type Add Games… and Locate… offer: the imported types for .cue, .m3u and .exe, then every type
    /// the system gives those extensions and .iso (`GameFormat.fileExtensions`), each once.
    public static var games: [UTType] {
        offered(imported: [cueSheet, discPlaylist, program]) { fileExtension in
            UTType.types(tag: fileExtension, tagClass: .filenameExtension, conformingTo: nil)
        }
    }

    /// The types offered: `imported` first, then each type `lookUp` gives one of the library's extensions,
    /// in the extensions' order, each once. Never a .bin's: a track comes with its cue sheet. Pure, so the
    /// tests run it over a scripted lookup and never ask the system's type database.
    static func offered<Kind: Hashable>(imported: [Kind], lookUp: (String) -> [Kind]) -> [Kind] {
        var kinds = imported
        for fileExtension in GameFormat.fileExtensions {
            for kind in lookUp(fileExtension) where !kinds.contains(kind) {
                kinds.append(kind)
            }
        }
        return kinds
    }
}
