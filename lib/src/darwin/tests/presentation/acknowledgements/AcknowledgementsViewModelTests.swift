// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import Foundation
import PresentationAcknowledgements
import Testing

@MainActor
@Suite struct AcknowledgementsViewModelTests {
    @Test func withNoEntriesTheScreenSaysSo() {
        let screen = AcknowledgementsViewModel()
        #expect(screen.state == .empty)
        #expect(screen.emptyMessage == "iStation includes no third-party code yet.")
    }

    @Test func entriesAreListedInOrder() {
        let entries = ["First", "Second"].map {
            Acknowledgement(name: $0, licence: "MIT", notice: "Notice", source: URL(fileURLWithPath: "/\($0)"))
        }
        let screen = AcknowledgementsViewModel(entries: entries)
        #expect(screen.state == .listed)
        #expect(screen.entries.map(\.name) == ["First", "Second"])
    }
}

@Suite struct AcknowledgementListTests {
    private let json = Data("""
    [
      {"name": "iStation", "licence": "MIT", "source": "https://example.org/istation", "apps": ["macOS", "iOS"], "notice": "MIT License"},
      {"name": "Play!", "licence": "BSD-2-Clause", "source": "https://example.org/play", "apps": ["macOS"], "notice": "Copyright (c) 2006-2026"}
    ]
    """.utf8)

    @Test func eachAppGetsOnlyTheEntriesItCarries() throws {
        #expect(try Acknowledgement.list(from: json, for: "macOS").map(\.name) == ["iStation", "Play!"])
        #expect(try Acknowledgement.list(from: json, for: "iOS").map(\.name) == ["iStation"])
    }

    @Test func theCommittedListDecodesForBothApps() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("apps/Acknowledgements.json")
        let data = try Data(contentsOf: url)
        let macOS = try Acknowledgement.list(from: data, for: "macOS")
        let iOS = try Acknowledgement.list(from: data, for: "iOS")
        #expect(macOS.map(\.name).prefix(2) == ["iStation", "ProjectPSX"])
        #expect(!iOS.contains { $0.licence == "BSD-2-Clause" }) // Play! is macOS-only
        #expect(macOS.allSatisfy { !$0.notice.isEmpty })
    }

    @Test func aMissingBundleListIsNoEntries() {
        #expect(Acknowledgement.bundled(for: "macOS", in: Bundle(for: Marker.self)).isEmpty)
    }
}

private final class Marker {}
