// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import Foundation
import Testing

/// The docs and the tests tree may not drift from the module map (ADRs 0002, 0004).
@Suite("Layer context") struct LayerContextTests {
    let map: ModuleMap

    init() throws {
        map = try ModuleMap.load()
    }

    @Test("Each source layer card's Modules line names exactly the layer's modules")
    func sourceCardsListTheMappedModules() {
        var violations = Violations()
        for layer in map.layers {
            let path = "source/\(layer)/CLAUDE.md"
            guard let card = Repository.text(Repository.package.appendingPathComponent(path)) else {
                violations.add("missing card", path, "no layer card")
                continue
            }
            guard let line = card.components(separatedBy: .newlines).first(where: { $0.hasPrefix("**Modules:**") }) else {
                violations.add("card drift", path, "has no **Modules:** line")
                continue
            }
            let listed = Set(Pattern.backticked(in: line))
            let mapped = Set(map.modules(in: layer).map(\.directory))
            for missing in mapped.subtracting(listed).sorted() {
                violations.add("card drift", path, "Modules line is missing `\(missing)`")
            }
            for extra in listed.subtracting(mapped).sorted() {
                violations.add("card drift", path, "Modules line names `\(extra)`, which is not a \(layer) module")
            }
        }
        #expect(violations.isEmpty, "\(violations.report)")
    }

    @Test("Every test layer has its card")
    func testCardsExist() {
        var violations = Violations()
        for layer in map.layers where !Repository.exists(Repository.package.appendingPathComponent("tests/\(layer)/CLAUDE.md")) {
            violations.add("missing card", "tests/\(layer)/CLAUDE.md", "no test layer card")
        }
        #expect(violations.isEmpty, "\(violations.report)")
    }

    @Test("ADR 0002's table equals the map")
    func theModuleMapADRMatchesTheMap() {
        var violations = Violations()
        let path = "documentation/istation/adrs/module-map.md"
        guard let adr = Repository.text(Repository.root.appendingPathComponent(path)) else {
            violations.add("missing ADR", path, "unreadable")
            #expect(violations.isEmpty, "\(violations.report)")
            return
        }
        var rows: [String: (layer: String, uses: Set<String>)] = [:]
        for row in Pattern.captures(#"^\| ([a-z]+) \| `([a-z0-9]+)` \| (.*) \|$"#, in: adr, options: [.anchorsMatchLines]) {
            guard let layer = row[0], let directory = row[1] else { continue }
            rows["\(layer)/\(directory)"] = (layer, Set(Pattern.backticked(in: row[2] ?? "")))
        }
        let mapped = Dictionary(uniqueKeysWithValues: map.modules.map { ("\($0.layer)/\($0.directory)", $0) })
        for key in Set(mapped.keys).subtracting(rows.keys).sorted() {
            violations.add("ADR drift", path, "has no row for \(key)")
        }
        for key in Set(rows.keys).subtracting(mapped.keys).sorted() {
            violations.add("ADR drift", path, "has a row for \(key), which is not in the map")
        }
        for (key, module) in mapped {
            guard let row = rows[key] else { continue }
            if row.uses != Set(module.uses) {
                violations.add("ADR drift", path, "\(key) may depend on \(row.uses.sorted()), the map says \(module.uses.sorted())")
            }
        }
        #expect(violations.isEmpty, "\(violations.report)")
    }

    @Test("The tests tree mirrors the source tree")
    func testsMirrorTheSource() {
        var violations = Violations()
        for module in map.modules where Repository.swiftFiles(under: module.testPath).isEmpty {
            violations.add("hole in the mirror", module.testPath, "\(module.target) has no tests")
        }
        let tests = Repository.package.appendingPathComponent("tests")
        for directory in Repository.subdirectories(of: tests) where !map.layers.contains(directory) && !["support", "architecture"].contains(directory) {
            violations.add("unknown directory", "tests/\(directory)", "is neither a layer, support nor architecture")
        }
        for layer in map.layers {
            let mapped = Set(map.modules(in: layer).map(\.directory))
            for directory in Repository.subdirectories(of: tests.appendingPathComponent(layer)) where !mapped.contains(directory) {
                violations.add("orphan tests", "tests/\(layer)/\(directory)", "mirrors no module")
            }
        }
        let supports = Set(map.supports.map { $0.name.lowercased() })
        for directory in Repository.subdirectories(of: tests.appendingPathComponent("support")) where !supports.contains(directory) {
            violations.add("unmapped support", "tests/support/\(directory)", "has no Support row in Package.swift")
        }
        #expect(violations.isEmpty, "\(violations.report)")
    }

    @Test("The Xcode project's macOS Personal scheme tests exactly every test target")
    func theXcodeSchemeTestsEveryTarget() {
        var violations = Violations()
        let path = "iStation.xcodeproj/xcshareddata/xcschemes/macOS Personal.xcscheme"
        guard let scheme = Repository.text(Repository.root.appendingPathComponent(path)) else {
            violations.add("scheme drift", path, "unreadable")
            #expect(violations.isEmpty, "\(violations.report)")
            return
        }
        let testables = Pattern.captures(#"<TestableReference[^<]*<BuildableReference[^>]*BlueprintIdentifier = "([A-Za-z0-9]+)""#, in: scheme)
            .compactMap { $0.first ?? nil }
        let expected = Set(map.modules.map { $0.target + "Tests" } + ["ArchitectureTests"])
        for missing in expected.subtracting(testables).sorted() {
            violations.add("scheme drift", path, "does not test \(missing)")
        }
        for extra in Set(testables).subtracting(expected).sorted() {
            violations.add("scheme drift", path, "tests \(extra), which is not a test target")
        }
        #expect(violations.isEmpty, "\(violations.report)")
    }

    @Test("ADR 0001 lists the layers in the map's order")
    func adr0001ListsTheLayersInOrder() {
        let path = "documentation/istation/adrs/layer-enforcement.md"
        let adr = Repository.text(Repository.root.appendingPathComponent(path)) ?? ""
        let listed = Pattern.captures(#"^\d\. \*\*([A-Za-z]+)\*\*"#, in: adr, options: [.anchorsMatchLines])
            .compactMap { $0.first ?? nil }.map { $0.lowercased() }
        #expect(listed == map.layers, "[ADR drift] \(path): lists \(listed), the map's layers are \(map.layers)")
    }
}
