// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import Foundation
import PresentationStyles

// The design as the tokens tests read it: json/tokens.json and the prototype's ICON set, found by
// their repository paths. Reads files only.

enum Design {
    /// lib/documentation/design/darwin, located from this file (lib/src/darwin/tests/presentation/styles/Design.swift).
    static let folder = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("documentation/design/darwin")

    struct Unreadable: Error, CustomStringConvertible {
        let description: String
    }

    /// tokens.json, parsed.
    static func tokens() throws -> [String: Any] {
        let url = folder.appendingPathComponent("json/tokens.json")
        guard let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any] else {
            throw Unreadable(description: "\(url.path) is not a JSON object")
        }
        return object
    }

    /// The keys of the prototype's `var ICON = { … };` in html/main.html, in their order.
    static func iconKeys() throws -> [String] {
        let url = folder.appendingPathComponent("html/main.html")
        let lines = try String(contentsOf: url, encoding: .utf8).components(separatedBy: .newlines)
        guard let start = lines.firstIndex(where: { $0.hasPrefix("var ICON = {") }),
              let end = lines[start...].firstIndex(where: { $0.hasPrefix("};") }) else {
            throw Unreadable(description: "\(url.path) has no ICON set")
        }
        return lines[(start + 1)..<end].compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let colon = trimmed.firstIndex(of: ":") else { return nil }
            return String(trimmed[..<colon])
        }
    }

    /// A color as tokens.json writes it, `#RRGGBB` or `#RRGGBBAA`.
    static func rgba(_ hex: String) -> RGBA? {
        guard hex.hasPrefix("#"), hex.count == 7 || hex.count == 9, let value = UInt32(hex.dropFirst(), radix: 16) else { return nil }
        return hex.count == 7 ? .rgb(value) : .rgba(value)
    }

    /// WCAG 2's relative luminance, computed as the design's tools/dc.mjs computes it (alpha ignored).
    static func luminance(_ color: RGBA) -> Double {
        func channel(_ value: UInt8) -> Double {
            let c = Double(value) / 255
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(color.red) + 0.7152 * channel(color.green) + 0.0722 * channel(color.blue)
    }

    /// WCAG 2's contrast ratio between two colors.
    static func contrast(_ a: RGBA, _ b: RGBA) -> Double {
        let (x, y) = (luminance(a), luminance(b))
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }
}
