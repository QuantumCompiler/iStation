import Foundation
import Testing

/// iStation's own laws: installed emulators stay separate programs, external code joins only after a
/// licence review, and the repository carries no Sony files (ADR 0010); tests and previews never reach the real home folder (ADR 0004).
@Suite("Project rules") struct ProjectRulesTests {
    @Test("Only InfrastructureProcess starts a process, and nothing loads code at runtime")
    func onlyInfrastructureProcessSpawnsProcesses() {
        var violations = Violations()
        let spawning = #"\bProcess\s*\(|\bposix_spawn|\bNSTask\b|\bdlopen\s*\(|\bsystem\s*\("#
        for file in Repository.swiftFiles(under: "source") where !file.path.hasPrefix("source/infrastructure/process/") {
            for (number, line) in file.lines.enumerated() where Pattern.matches(spawning, in: line) {
                violations.add("process outside InfrastructureProcess", "\(file.path):\(number + 1)", line.trimmingCharacters(in: .whitespaces))
            }
        }
        #expect(violations.isEmpty, "\(violations.report)")
    }

    /// Each addition is licence-reviewed first, in ADR 0010's allow-list.
    static let allowedPackages: [String] = []

    @Test("The package links no external code beyond ADR 0010's allow-list")
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

    @Test("Only InfrastructureLocations reaches the real home folder, and only the entry point asks it to")
    func onlyLocationsReachesTheRealHome() {
        var violations = Violations()
        let realHome = #"homeDirectoryForCurrentUser|NSHomeDirectory|applicationSupportDirectory|FileManager\.default\.urls\(for"#
        let realUser = #"\.user\(\)"#
        let files = Repository.swiftFiles(under: "source") + Repository.swiftFiles(under: "tests").filter { !$0.path.hasPrefix("tests/architecture/") }
        for file in files {
            for (number, line) in file.lines.enumerated() {
                if Pattern.matches(realHome, in: line), !file.path.hasPrefix("source/infrastructure/locations/") {
                    violations.add("real home outside Locations", "\(file.path):\(number + 1)", line.trimmingCharacters(in: .whitespaces))
                }
                if Pattern.matches(realUser, in: line), !file.path.hasPrefix("source/main/"), !file.path.hasPrefix("source/infrastructure/locations/") {
                    violations.add("real user outside the entry point", "\(file.path):\(number + 1)", line.trimmingCharacters(in: .whitespaces))
                }
            }
        }
        #expect(violations.isEmpty, "\(violations.report)")
    }
}
