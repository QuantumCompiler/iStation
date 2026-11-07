// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import Foundation

// The repository on disk as the architecture checks see it: the module map parsed from
// Package.swift, the Swift files of every module, and their imports. Reads files only.

enum Repository {
    /// src/istation, located from this file (tests/architecture/Repository.swift).
    static let package = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    static let root = package.deletingLastPathComponent().deletingLastPathComponent()
    static let docs = root.appendingPathComponent("documentation/istation")

    /// Package.swift, or the planted copy named by ISTATION_ARCHITECTURE_MANIFEST. The override exists
    /// to prove the rules SwiftPM itself refuses to load (a cycle, styles leaning on a sibling): the
    /// checks parse the planted copy while the build uses the real manifest (DEVELOPER.md).
    static var manifest: URL {
        ProcessInfo.processInfo.environment["ISTATION_ARCHITECTURE_MANIFEST"].map { URL(fileURLWithPath: $0) }
            ?? package.appendingPathComponent("Package.swift")
    }

    static func text(_ url: URL) -> String? {
        try? String(contentsOf: url, encoding: .utf8)
    }

    static func exists(_ url: URL, directory: Bool = false) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue == directory
    }

    /// The names of the directories directly inside `url`.
    static func subdirectories(of url: URL) -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
        return names.filter { exists(url.appendingPathComponent($0), directory: true) }.sorted()
    }

    /// Every .swift file under `relativePath` of the package, recursively.
    static func swiftFiles(under relativePath: String) -> [SourceFile] {
        let base = package.appendingPathComponent(relativePath)
        guard let enumerator = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil) else { return [] }
        var files: [SourceFile] = []
        while let url = enumerator.nextObject() as? URL {
            guard url.pathExtension == "swift", let text = text(url) else { continue }
            let relative = String(url.standardizedFileURL.path.dropFirst(package.standardizedFileURL.path.count + 1))
            files.append(SourceFile(path: relative, text: text))
        }
        return files.sorted { $0.path < $1.path }
    }
}

struct SourceFile {
    /// Relative to the package, e.g. "source/data/store/LibraryStore.swift".
    let path: String
    let text: String

    var lines: [String] { text.components(separatedBy: .newlines) }

    /// The modules this file imports.
    var imports: [String] {
        lines.compactMap { line in
            Pattern.captures(#"^\s*(?:@\w+\s+)*import\s+(?:(?:class|struct|enum|protocol|typealias|func|var|let)\s+)?([A-Za-z_][A-Za-z0-9_]*)"#, in: line).first?.first ?? nil
        }
    }

    /// True when the file sits in a directory with this name, e.g. "ViewModels".
    func isInside(_ directory: String) -> Bool {
        path.split(separator: "/").dropLast().contains { $0 == directory }
    }
}

enum Pattern {
    /// Every match's capture groups (nil for a group that did not take part).
    static func captures(_ pattern: String, in text: String, options: NSRegularExpression.Options = []) -> [[String?]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).map { match in
            (1..<max(1, match.numberOfRanges)).map { index in
                Range(match.range(at: index), in: text).map { String(text[$0]) }
            }
        }
    }

    /// True when `pattern` matches anywhere in `text`; `^` and `$` match at line ends.
    static func matches(_ pattern: String, in text: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return false }
        return regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    /// The double-quoted names in a list such as `"DataCatalog", "DataEmulators"`.
    static func names(in list: String?) -> [String] {
        guard let list else { return [] }
        return captures(#""([A-Za-z0-9]+)""#, in: list).compactMap { $0.first ?? nil }
    }

    /// The backticked names on a line, e.g. "`bytes` (…), `locations`".
    static func backticked(in line: String) -> [String] {
        captures(#"`([^`]+)`"#, in: line).compactMap { $0.first ?? nil }
    }
}

// MARK: - The module map

struct MapModule {
    let layer: String
    let name: String
    let uses: [String]
    let testSupport: [String]
    /// `none`, `projectPSX` or `play` (ADR 0014).
    let derivedFrom: String

    var target: String { layer.prefix(1).uppercased() + layer.dropFirst() + name }
    var directory: String { name.lowercased() }
    var sourcePath: String { "source/\(layer)/\(directory)" }
    var testPath: String { "tests/\(layer)/\(directory)" }
}

struct MapSupport {
    let layer: String
    let name: String
    let uses: [String]

    var target: String { "Support" + name }
    var path: String { "tests/support/\(name.lowercased())" }
}

/// Package.swift's module map: the layer law's one declaration (ADR 0002).
struct ModuleMap {
    let layers: [String]
    let modules: [MapModule]
    let supports: [MapSupport]

    static let uiFrameworks: Set<String> = ["SwiftUI", "AppKit", "UIKit", "Cocoa"]

    static func load() throws -> ModuleMap {
        struct Unreadable: Error, CustomStringConvertible { let description: String }
        guard let manifest = Repository.text(Repository.manifest) else {
            throw Unreadable(description: "Package.swift is unreadable")
        }
        let layerList = Pattern.captures(#"enum Layer: String, CaseIterable \{ case ([a-z, ]+) \}"#, in: manifest).first?.first ?? nil
        let layers = (layerList ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        var modules: [MapModule] = []
        var supports: [MapSupport] = []
        for line in manifest.components(separatedBy: .newlines) {
            if let row = Pattern.captures(
                #"^\s*Module\(\.([a-z]+), "([A-Za-z0-9]+)"(?:, uses: \[([^\]]*)\])?(?:, testSupport: \[([^\]]*)\])?(?:, derivedFrom: \.([A-Za-z]+))?\),\s*$"#, in: line
            ).first, let layer = row[0], let name = row[1] {
                modules.append(MapModule(layer: layer, name: name, uses: Pattern.names(in: row[2]), testSupport: Pattern.names(in: row[3]), derivedFrom: row[4] ?? "none"))
            } else if let row = Pattern.captures(
                #"^\s*Support\(\.([a-z]+), "([A-Za-z0-9]+)"(?:, uses: \[([^\]]*)\])?\),\s*$"#, in: line
            ).first, let layer = row[0], let name = row[1] {
                supports.append(MapSupport(layer: layer, name: name, uses: Pattern.names(in: row[2])))
            }
        }
        return ModuleMap(layers: layers, modules: modules, supports: supports)
    }

    func module(_ target: String) -> MapModule? { modules.first { $0.target == target } }
    func support(_ target: String) -> MapSupport? { supports.first { $0.target == target } }

    /// The layer's position, lowest first; nil for anything not in the map.
    func rank(ofLayer layer: String) -> Int? { layers.firstIndex(of: layer) }

    /// The layer rank of a module or support target.
    func rank(of target: String) -> Int? {
        if let module = module(target) { return rank(ofLayer: module.layer) }
        if let support = support(target) { return rank(ofLayer: support.layer) }
        return nil
    }

    func modules(in layer: String) -> [MapModule] { modules.filter { $0.layer == layer } }

    /// Every target name the package defines, so imports of system modules can be told apart.
    var packageTargets: Set<String> {
        Set(modules.map(\.target) + modules.map { $0.target + "Tests" } + supports.map(\.target) + ["ArchitectureTests"])
    }
}

/// Collects rule violations and reports them as one failure that names every file.
struct Violations {
    private(set) var lines: [String] = []

    mutating func add(_ rule: String, _ path: String, _ detail: String) {
        lines.append("[\(rule)] \(path): \(detail)")
    }

    var isEmpty: Bool { lines.isEmpty }
    var report: String { "\n" + lines.joined(separator: "\n") }
}
