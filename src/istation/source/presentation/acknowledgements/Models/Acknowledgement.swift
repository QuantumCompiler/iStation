// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import Foundation

/// One component whose notice the apps carry: its name, licence, notice text and source.
public struct Acknowledgement: Identifiable, Equatable, Sendable {
    public var id: String { name }
    public let name: String
    /// An SPDX licence identifier, e.g. "MIT".
    public let licence: String
    public let notice: String
    public let source: URL

    public init(name: String, licence: String, notice: String, source: URL) {
        self.name = name
        self.licence = licence
        self.notice = notice
        self.source = source
    }

    /// The entries of an acknowledgements list (`src/istation/apps/Acknowledgements.json`) that one
    /// app carries, in the list's order. `app` is "macOS" or "iOS".
    public static func list(from data: Data, for app: String) throws -> [Acknowledgement] {
        try JSONDecoder().decode([Entry].self, from: data)
            .filter { $0.apps.contains(app) }
            .map { Acknowledgement(name: $0.name, licence: $0.licence, notice: $0.notice, source: $0.source) }
    }

    /// The list bundled with the running app, or no entries when it is missing or unreadable.
    public static func bundled(for app: String, in bundle: Bundle = .main) -> [Acknowledgement] {
        guard let url = bundle.url(forResource: "Acknowledgements", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? list(from: data, for: app)
        else { return [] }
        return entries
    }

    private struct Entry: Decodable {
        let name: String
        let licence: String
        let source: URL
        let apps: [String]
        let notice: String
    }
}
