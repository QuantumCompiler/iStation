// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import DataLibrary
import Foundation
@testable import PresentationLibrary
import Testing

/// The kinds of file the library's choosers offer: the macOS app's imported types, as its `Info.plist`
/// declares them — read here by its repository path, read-only — then whatever the system calls a file
/// with one of the library's extensions, each once and never a track's. The system's own answers are
/// scripted: a test never asks the type database, whose answers change with the apps a machine has.
@Suite struct GameFileTypesTests {
    /// apps/macos/Info.plist, located from this file (lib/src/darwin/tests/presentation/library/GameFileTypesTests.swift).
    static let infoPlist = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("apps/macos/Info.plist")

    /// What a machine's type database might answer, by extension: types that carry other extensions too
    /// (.m3u8, .vhd), and a type two extensions share.
    static let system: [String: [String]] = [
        "cue": ["local.istation.cue-sheet"],
        "iso": ["public.iso-image"],
        "m3u": ["public.m3u-playlist", "com.apple.music.m3u-playlist"],
        "exe": ["com.microsoft.windows-executable", "com.vmware.foreign.vhd", "public.m3u-playlist"],
        "bin": ["com.apple.macbinary-archive"],
    ]

    @Test func theChoosersOfferTheImportedTypesThenTheSystemsEachOnce() {
        let imported = [GameFileTypes.cueSheetIdentifier, GameFileTypes.discPlaylistIdentifier, GameFileTypes.programIdentifier]
        var asked: [String] = []
        let offered = GameFileTypes.offered(imported: imported) { fileExtension in
            asked.append(fileExtension)
            return Self.system[fileExtension] ?? []
        }
        #expect(offered == [
            "local.istation.cue-sheet", "local.istation.disc-playlist", "local.istation.ps-exe",
            "public.iso-image", "public.m3u-playlist", "com.apple.music.m3u-playlist",
            "com.microsoft.windows-executable", "com.vmware.foreign.vhd",
        ])
        #expect(asked == GameFormat.fileExtensions, "each of the library's extensions, in order, and never a .bin")
    }

    @Test func theAppDeclaresEachImportedTypeForItsExtension() throws {
        let data = try Data(contentsOf: Self.infoPlist)
        let plist = try #require(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        let declarations = try #require(plist["UTImportedTypeDeclarations"] as? [[String: Any]])
        var declared: [String: (extensions: [String], conformsTo: [String])] = [:]
        for declaration in declarations {
            let identifier = try #require(declaration["UTTypeIdentifier"] as? String)
            let tags = declaration["UTTypeTagSpecification"] as? [String: Any]
            declared[identifier] = (
                tags?["public.filename-extension"] as? [String] ?? [],
                declaration["UTTypeConformsTo"] as? [String] ?? []
            )
        }
        #expect(declared.count == 4)
        #expect(declared[GameFileTypes.cueSheetIdentifier]?.extensions == ["cue"])
        #expect(declared[GameFileTypes.cueSheetIdentifier]?.conformsTo == ["public.plain-text"])
        #expect(declared[GameFileTypes.discTrackIdentifier]?.extensions == ["bin"])
        #expect(declared[GameFileTypes.discTrackIdentifier]?.conformsTo == ["public.data"])
        #expect(declared[GameFileTypes.discPlaylistIdentifier]?.extensions == ["m3u"])
        #expect(declared[GameFileTypes.discPlaylistIdentifier]?.conformsTo == ["public.plain-text"])
        #expect(declared[GameFileTypes.programIdentifier]?.extensions == ["exe"])
        #expect(declared[GameFileTypes.programIdentifier]?.conformsTo == ["public.data"])
    }
}
