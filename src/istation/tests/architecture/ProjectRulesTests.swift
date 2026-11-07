// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import Foundation
import Testing

/// iStation's own laws: nothing in the package or the apps starts a process or loads code, external
/// code joins only after a licence review, and the repository carries no Sony files (ADR 0013); the
/// package never reaches the real home folder (ADR 0004); release builds carry no tools and no
/// debugging entitlements (ADR 0016).
@Suite("Project rules") struct ProjectRulesTests {
    /// The Swift files the apps are built from: the package's sources and the app targets' own.
    static var shippedFiles: [SourceFile] {
        Repository.swiftFiles(under: "source") + Repository.swiftFiles(under: "apps")
    }

    @Test("Nothing in the package or the apps starts a process or loads code at runtime")
    func nothingSpawnsProcesses() {
        var violations = Violations()
        let spawning = #"\bProcess\s*\(|\bposix_spawn|\bNSTask\b|\bdlopen\s*\(|(?<![.\w])system\s*\("#  // C's system(), not Font.system(…)
        for file in Self.shippedFiles {
            for (number, line) in file.lines.enumerated() where Pattern.matches(spawning, in: line) {
                violations.add("process in a shipped file", "\(file.path):\(number + 1)", line.trimmingCharacters(in: .whitespaces))
            }
        }
        #expect(violations.isEmpty, "\(violations.report)")
    }

    /// Each addition is licence-reviewed first, in ADR 0013's allow-list.
    static let allowedPackages: [String] = []

    @Test("The package links no external code beyond ADR 0013's allow-list")
    func noExternalPackages() {
        var violations = Violations()
        let manifest = Repository.text(Repository.manifest) ?? ""
        for (number, line) in manifest.components(separatedBy: .newlines).enumerated() {
            if line.contains(".binaryTarget(") || line.contains(".systemLibrary(") {
                violations.add("external code", "Package.swift:\(number + 1)", line.trimmingCharacters(in: .whitespaces))
            }
            if line.contains(".package("), !Self.allowedPackages.contains(where: { line.contains($0) }) {
                violations.add("external package", "Package.swift:\(number + 1)", line.trimmingCharacters(in: .whitespaces))
            }
        }
        #expect(violations.isEmpty, "\(violations.report)")
    }

    @Test("The repository holds no disc images, BIOS or system software")
    func noGameOrFirmwareFiles() {
        var violations = Violations()
        let banned: Set<String> = ["iso", "bin", "img", "cue", "m3u", "chd", "cso", "zso", "gz", "pbp", "ecm", "pup", "rom", "mec", "nvm"]
        let skipped: Set<String> = [".git", ".build", ".swiftpm", "build", "DerivedData"]
        let root = Repository.root.standardizedFileURL
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        while let url = enumerator?.nextObject() as? URL {
            if skipped.contains(url.lastPathComponent) {
                enumerator?.skipDescendants()
                continue
            }
            if banned.contains(url.pathExtension.lowercased()) {
                violations.add("game or firmware file", String(url.standardizedFileURL.path.dropFirst(root.path.count + 1)), "users supply their own (SPEC non-goals)")
            }
        }
        #expect(violations.isEmpty, "\(violations.report)")
    }

    @Test("Neither the package nor its tests reach the real home folder")
    func noRealHome() {
        var violations = Violations()
        let realHome = #"homeDirectoryForCurrentUser|NSHomeDirectory|applicationSupportDirectory|FileManager\.default\.urls\(for"#
        let files = Repository.swiftFiles(under: "source") + Repository.swiftFiles(under: "tests").filter { !$0.path.hasPrefix("tests/architecture/") }
        for file in files {
            for (number, line) in file.lines.enumerated() where Pattern.matches(realHome, in: line) {
                violations.add("real home in the package", "\(file.path):\(number + 1)", line.trimmingCharacters(in: .whitespaces))
            }
        }
        #expect(violations.isEmpty, "\(violations.report)")
    }

    /// Modules that exist only in personal builds: their imports sit under `#if PERSONAL_BUILD`.
    static let toolModules: Set<String> = ["DataTracing"]

    @Test("Tools and debug views compile only into personal builds")
    func toolsArePersonalOnly() {
        var violations = Violations()
        for file in Self.shippedFiles {
            var frames: [(condition: String, inElse: Bool)] = []
            for (number, line) in file.lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("#if ") {
                    frames.append((String(trimmed.dropFirst(4)), false))
                } else if trimmed.hasPrefix("#elseif "), !frames.isEmpty {
                    frames[frames.count - 1] = (String(trimmed.dropFirst(8)), false)
                } else if trimmed == "#else", !frames.isEmpty {
                    frames[frames.count - 1].inElse = true
                } else if trimmed == "#endif", !frames.isEmpty {
                    frames.removeLast()
                } else if let imported = SourceFile(path: file.path, text: line).imports.first, Self.toolModules.contains(imported) {
                    let guarded = frames.contains { !$0.inElse && Pattern.matches(#"(^|[\s(&|])PERSONAL_BUILD\b"#, in: $0.condition) }
                    if !guarded {
                        violations.add("tool in a release build", "\(file.path):\(number + 1)", "imports \(imported) outside #if PERSONAL_BUILD")
                    }
                }
            }
            if file.isInside("Debug"), file.lines.first(where: { !$0.isEmpty && !$0.hasPrefix("//") }) != "#if PERSONAL_BUILD" {
                violations.add("tool in a release build", file.path, "a debug view that does not open with #if PERSONAL_BUILD")
            }
        }
        #expect(violations.isEmpty, "\(violations.report)")
    }

    @Test("App Store entitlements never allow unsigned executable memory or debugging, and every app has both routines")
    func appStoreEntitlementsAreClean() {
        var violations = Violations()
        // macOS spells the debugging key com.apple.security.get-task-allow, iOS plain get-task-allow.
        let forbidden = ["com.apple.security.cs.allow-unsigned-executable-memory", "com.apple.security.get-task-allow", "<key>get-task-allow</key>"]
        let root = Repository.root.standardizedFileURL
        let skipped: Set<String> = [".git", ".build", ".swiftpm", "build", "DerivedData"]
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        var appStoreFiles = 0
        while let url = enumerator?.nextObject() as? URL {
            if skipped.contains(url.lastPathComponent) {
                enumerator?.skipDescendants()
                continue
            }
            guard url.lastPathComponent == "AppStore.entitlements", let text = Repository.text(url) else { continue }
            appStoreFiles += 1
            let path = String(url.standardizedFileURL.path.dropFirst(root.path.count + 1))
            for key in forbidden where text.contains(key) {
                violations.add("debugging in an App Store build", path, "carries \(key)")
            }
        }
        if appStoreFiles == 0 { violations.add("debugging in an App Store build", "src/istation/apps", "no AppStore.entitlements found") }
        let apps = Repository.package.appendingPathComponent("apps")
        for app in Repository.subdirectories(of: apps) where app != "Config" {
            for routine in ["AppStore", "Personal"] where !Repository.exists(apps.appendingPathComponent("\(app)/\(routine).entitlements")) {
                violations.add("missing routine", "src/istation/apps/\(app)", "has no \(routine).entitlements")
            }
        }
        #expect(violations.isEmpty, "\(violations.report)")
    }

    // MARK: - Provenance (ADR 0014)

    /// Each reference a module may be ported from: its repository, its licence, its entry in the list.
    static let references: [String: (repository: String, licence: String, acknowledgement: String)] = [
        "projectPSX": ("BluestormDNA/ProjectPSX/", "MIT", "ProjectPSX"),
        "play": ("jpd002/Play-/", "BSD-2-Clause", "Play!"),
    ]

    /// Every Swift file whose header these rules read: the package's and the apps'.
    static var headedFiles: [SourceFile] {
        Repository.swiftFiles(under: "source") + Repository.swiftFiles(under: "tests") + Repository.swiftFiles(under: "apps")
    }

    /// The licence a file's first line names, if it is an SPDX header.
    static func licence(of file: SourceFile) -> String? {
        Pattern.captures(#"^// SPDX-License-Identifier: (\S+)$"#, in: file.lines.first ?? "").first?.first ?? nil
    }

    @Test("Every Swift file opens with its SPDX header, and every licence it names has its text")
    func everyFileHasItsHeader() {
        var violations = Violations()
        for file in Self.headedFiles {
            guard let licence = Self.licence(of: file) else {
                violations.add("missing SPDX header", file.path, "line 1 is not `// SPDX-License-Identifier: <id>`")
                continue
            }
            if file.lines.count < 2 || !file.lines[1].hasPrefix("// SPDX-FileCopyrightText: ") {
                violations.add("missing SPDX header", file.path, "line 2 is not `// SPDX-FileCopyrightText: <holders>`")
            }
            if !Repository.exists(Repository.root.appendingPathComponent("LICENSES/\(licence).txt")) {
                violations.add("unknown licence", file.path, "names \(licence), which has no LICENSES/\(licence).txt")
            }
        }
        #expect(violations.isEmpty, "\(violations.report)")
    }

    @Test("Every file in a ported module names its source file and carries its reference's licence")
    func portedModulesNameTheirSources() throws {
        var violations = Violations()
        let map = try ModuleMap.load()
        for module in map.modules where module.derivedFrom != "none" {
            guard let reference = Self.references[module.derivedFrom] else {
                violations.add("unknown reference", "Package.swift", "\(module.target) derives from \(module.derivedFrom)")
                continue
            }
            for file in Repository.swiftFiles(under: module.sourcePath) {
                let provenance = file.lines.first { $0.hasPrefix("// Ported from ") }
                if provenance.map({ Pattern.matches(#"^// Ported from "# + NSRegularExpression.escapedPattern(for: reference.repository) + #"\S+ — .+$"#, in: $0) }) != true {
                    violations.add("missing provenance", file.path, "has no `// Ported from \(reference.repository)<path> — <its copyright line>`")
                }
                if Self.licence(of: file) != reference.licence {
                    violations.add("wrong licence", file.path, "a file ported from \(module.derivedFrom) is \(reference.licence)")
                }
            }
        }
        #expect(violations.isEmpty, "\(violations.report)")
    }

    @Test("Every licence a header names, and every reference the map names, is in the acknowledgements list")
    func everyLicenceIsAcknowledged() throws {
        var violations = Violations()
        let path = "src/istation/apps/Acknowledgements.json"
        struct Entry: Decodable { let name: String; let licence: String; let notice: String; let apps: [String] }
        guard let data = try? Data(contentsOf: Repository.root.appendingPathComponent(path)),
              let entries = try? JSONDecoder().decode([Entry].self, from: data)
        else {
            violations.add("acknowledgements", path, "missing or unreadable")
            #expect(violations.isEmpty, "\(violations.report)")
            return
        }
        let listed = Set(entries.map(\.licence))
        for licence in Set(Self.headedFiles.compactMap(Self.licence)) where !listed.contains(licence) {
            violations.add("unacknowledged licence", path, "no entry carries \(licence), which a header names")
        }
        for module in try ModuleMap.load().modules where module.derivedFrom != "none" {
            if let reference = Self.references[module.derivedFrom], !entries.contains(where: { $0.name == reference.acknowledgement }) {
                violations.add("unacknowledged reference", path, "no \(reference.acknowledgement) entry for \(module.target)")
            }
        }
        for entry in entries where entry.notice.isEmpty || entry.apps.isEmpty {
            violations.add("acknowledgements", path, "\(entry.name) has no notice or no app")
        }
        #expect(violations.isEmpty, "\(violations.report)")
    }
}

