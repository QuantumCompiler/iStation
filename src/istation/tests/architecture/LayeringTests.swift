// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import Testing

/// The layer law (ADR 0001) over the module map (ADR 0002), and the Presentation shape (ADRs 0005, 0006).
/// Each test names its rule and every offending file.
@Suite("Layering") struct LayeringTests {
    let map: ModuleMap

    init() throws {
        map = try ModuleMap.load()
    }

    @Test("The map is not empty and every layer holds a module")
    func theMapIsNotEmpty() {
        var violations = Violations()
        if map.layers.isEmpty { violations.add("empty map", "Package.swift", "no Layer cases parsed") }
        if map.modules.isEmpty { violations.add("empty map", "Package.swift", "no Module rows parsed") }
        for layer in map.layers where map.modules(in: layer).isEmpty {
            violations.add("empty map", "Package.swift", "layer \(layer) has no module")
        }
        for module in map.modules where map.rank(ofLayer: module.layer) == nil {
            violations.add("unknown layer", "Package.swift", "\(module.target) is in unknown layer \(module.layer)")
        }
        #expect(violations.isEmpty, "\(violations.report)")
    }

    @Test("Every module has its source directory, and every source directory is a module")
    func everyModuleHasItsSourceDirectory() {
        var violations = Violations()
        for module in map.modules where Repository.swiftFiles(under: module.sourcePath).isEmpty {
            violations.add("missing module", module.sourcePath, "\(module.target) has no Swift files")
        }
        let source = Repository.package.appendingPathComponent("source")
        for directory in Repository.subdirectories(of: source) where !map.layers.contains(directory) {
            violations.add("unknown directory", "source/\(directory)", "is not a layer")
        }
        for layer in map.layers {
            let mapped = Set(map.modules(in: layer).map(\.directory))
            for directory in Repository.subdirectories(of: source.appendingPathComponent(layer)) where !mapped.contains(directory) {
                violations.add("unmapped module", "source/\(layer)/\(directory)", "has no Module row in Package.swift")
            }
        }
        #expect(violations.isEmpty, "\(violations.report)")
    }

    @Test("Declared edges point down, to modules that exist")
    func declaredEdgesPointDown() {
        var violations = Violations()
        for module in map.modules {
            let rank = map.rank(ofLayer: module.layer) ?? 0
            for use in module.uses {
                guard let used = map.module(use) else {
                    violations.add("unknown edge", "Package.swift", "\(module.target) uses \(use), which is not a module")
                    continue
                }
                if use == module.target {
                    violations.add("self edge", "Package.swift", "\(module.target) uses itself")
                } else if let usedRank = map.rank(ofLayer: used.layer), usedRank > rank {
                    violations.add("upward edge", "Package.swift", "\(module.target) (\(module.layer)) uses \(use) (\(used.layer))")
                }
            }
        }
        #expect(violations.isEmpty, "\(violations.report)")
    }

    @Test("Every import of a package module is declared, points down, and never names test code")
    func importsAreDeclared() {
        var violations = Violations()
        let targets = map.packageTargets
        for module in map.modules {
            let rank = map.rank(ofLayer: module.layer) ?? 0
            for file in Repository.swiftFiles(under: module.sourcePath) {
                for imported in file.imports where targets.contains(imported) && imported != module.target {
                    if map.support(imported) != nil || imported.hasSuffix("Tests") {
                        violations.add("imports test code", file.path, "imports \(imported)")
                    } else if let importedRank = map.rank(of: imported), importedRank > rank {
                        violations.add("upward import", file.path, "\(module.target) (\(module.layer)) imports \(imported)")
                    } else if !module.uses.contains(imported) {
                        violations.add("undeclared import", file.path, "\(module.target) imports \(imported), not in its uses")
                    }
                }
            }
        }
        #expect(violations.isEmpty, "\(violations.report)")
    }

    @Test("Every declared edge is used")
    func everyDeclaredEdgeIsUsed() {
        var violations = Violations()
        for module in map.modules {
            let imported = Set(Repository.swiftFiles(under: module.sourcePath).flatMap(\.imports))
            for use in module.uses where !imported.contains(use) {
                violations.add("unused edge", "Package.swift", "\(module.target) declares \(use) but never imports it")
            }
        }
        #expect(violations.isEmpty, "\(violations.report)")
    }

    @Test("The module graph has no cycles")
    func theModuleGraphHasNoCycles() {
        var violations = Violations()
        var state: [String: Int] = [:] // 1 visiting, 2 done
        func visit(_ target: String, _ path: [String]) {
            if state[target] == 1 {
                violations.add("cycle", "Package.swift", (path + [target]).joined(separator: " → "))
                return
            }
            guard state[target] == nil else { return }
            state[target] = 1
            for use in map.module(target)?.uses ?? [] { visit(use, path + [target]) }
            state[target] = 2
        }
        for module in map.modules { visit(module.target, []) }
        #expect(violations.isEmpty, "\(violations.report)")
    }

    @Test("UI frameworks are imported in Presentation only")
    func uiFrameworksStayInPresentation() {
        var violations = Violations()
        for module in map.modules where module.layer != "presentation" {
            for file in Repository.swiftFiles(under: module.sourcePath) {
                for imported in file.imports where ModuleMap.uiFrameworks.contains(imported) {
                    violations.add("UI framework below Presentation", file.path, "imports \(imported)")
                }
            }
        }
        #expect(violations.isEmpty, "\(violations.report)")
    }

    @Test("View-models and view models import no UI framework")
    func viewModelsImportNoUIFramework() {
        var violations = Violations()
        for module in map.modules(in: "presentation") {
            for file in Repository.swiftFiles(under: module.sourcePath) where file.isInside("ViewModels") || file.isInside("Models") {
                for imported in file.imports where ModuleMap.uiFrameworks.contains(imported) {
                    violations.add("UI framework in a view-model", file.path, "imports \(imported)")
                }
            }
        }
        #expect(violations.isEmpty, "\(violations.report)")
    }

    @Test("Every Presentation module has the MVVM shape")
    func presentationModulesHaveTheMVVMShape() {
        var violations = Violations()
        for module in map.modules(in: "presentation") {
            let root = Repository.package.appendingPathComponent(module.sourcePath)
            let isStyles = module.name == "Styles"
            let admitted: Set<String> = isStyles ? ["Components", "Previews"] : ["Views", "ViewModels", "Components", "Models", "Previews", "Debug"]
            let directories = Repository.subdirectories(of: root)
            for directory in directories where !admitted.contains(directory) {
                violations.add("MVVM shape", "\(module.sourcePath)/\(directory)", "is not an admitted directory (\(admitted.sorted().joined(separator: ", ")))")
            }
            for directory in directories where Repository.swiftFiles(under: "\(module.sourcePath)/\(directory)").isEmpty {
                violations.add("MVVM shape", "\(module.sourcePath)/\(directory)", "is empty")
            }
            guard !isStyles else { continue }
            for required in ["Views", "ViewModels"] where !directories.contains(required) {
                violations.add("MVVM shape", module.sourcePath, "has no \(required)/")
            }
            for file in Repository.swiftFiles(under: module.sourcePath) where file.path.split(separator: "/").count == 4 {
                violations.add("MVVM shape", file.path, "sits at the module root, outside Views/ and ViewModels/")
            }
        }
        #expect(violations.isEmpty, "\(violations.report)")
    }

    @Test("styles depends on no sibling Presentation module")
    func stylesDependsOnNoSibling() {
        var violations = Violations()
        for module in map.modules(in: "presentation") where module.name == "Styles" {
            for use in module.uses where map.module(use)?.layer == "presentation" {
                violations.add("styles depends on a sibling", "Package.swift", "PresentationStyles uses \(use)")
            }
        }
        #expect(violations.isEmpty, "\(violations.report)")
    }

    @Test("Views reach Business only through their view-model")
    func viewsDoNotReachBusiness() {
        var violations = Violations()
        for module in map.modules(in: "presentation") {
            for file in Repository.swiftFiles(under: module.sourcePath) where file.isInside("Views") || file.isInside("Components") {
                for imported in file.imports where map.module(imported)?.layer == "business" {
                    violations.add("view reaches Business", file.path, "imports \(imported)")
                }
            }
        }
        #expect(violations.isEmpty, "\(violations.report)")
    }

    @Test("Feature views take every color, font and size from styles")
    func tokensComeFromStyles() {
        var violations = Violations()
        let literal = #"Color\(\s*(red|white|hue|#)|Font\.system\(size:|\.system\(size:|\.font\(\.system\(\s*size|\.padding\(\s*\d|spacing:\s*\d|cornerRadius:\s*\d|lineWidth:\s*\d|(min|max|ideal)?[Ww]idth:\s*\d|(min|max|ideal)?[Hh]eight:\s*\d|\.opacity\(\s*0?\.\d"#
        for module in map.modules(in: "presentation") where module.name != "Styles" {
            for file in Repository.swiftFiles(under: module.sourcePath) where file.isInside("Views") || file.isInside("Components") {
                for (number, line) in file.lines.enumerated() where Pattern.matches(literal, in: line) {
                    violations.add("literal visual constant", "\(file.path):\(number + 1)", line.trimmingCharacters(in: .whitespaces))
                }
            }
        }
        #expect(violations.isEmpty, "\(violations.report)")
    }

    @Test("Every view has a named preview, and preview code is debug-only")
    func everyViewHasAPreview() {
        var violations = Violations()
        for module in map.modules(in: "presentation") {
            for file in Repository.swiftFiles(under: module.sourcePath) {
                let declaresView = Pattern.matches(#"^\s*(?:public\s+)?struct\s+\w+(?:<[^>]*>)?\s*:\s*View\b"#, in: file.text)
                if (file.isInside("Views") || file.isInside("Components")) && declaresView
                    && !Pattern.matches(#"#Preview\(""#, in: file.text) {
                    violations.add("view without a preview", file.path, "declares a View but no named #Preview(\"…\")")
                }
                if file.text.contains("#Preview") && !file.text.contains("#if DEBUG") {
                    violations.add("preview not debug-only", file.path, "has #Preview outside #if DEBUG")
                }
                if file.isInside("Previews") && file.lines.first(where: { !$0.isEmpty && !$0.hasPrefix("//") }) != "#if DEBUG" {
                    violations.add("preview not debug-only", file.path, "does not open with #if DEBUG")
                }
            }
        }
        #expect(violations.isEmpty, "\(violations.report)")
    }

    @Test("Tests obey the layer law: a test imports only its module, that module's edges and its declared support")
    func testsObeyTheLayerLaw() {
        var violations = Violations()
        let targets = map.packageTargets
        for module in map.modules {
            let rank = map.rank(ofLayer: module.layer) ?? 0
            for support in module.testSupport {
                if let supportRank = map.rank(of: support), map.support(support) != nil {
                    if supportRank > rank {
                        violations.add("upward test support", "Package.swift", "\(module.target)Tests uses \(support), above its layer")
                    }
                } else {
                    violations.add("unknown test support", "Package.swift", "\(module.target)Tests uses \(support), which is not a Support row")
                }
            }
            let allowed = Set([module.target] + module.uses + module.testSupport)
            for file in Repository.swiftFiles(under: module.testPath) {
                for imported in file.imports where targets.contains(imported) && !allowed.contains(imported) {
                    let upward = (map.rank(of: imported) ?? -1) > rank
                    violations.add(upward ? "upward test import" : "undeclared test import", file.path, "imports \(imported)")
                }
            }
        }
        for support in map.supports {
            let rank = map.rank(ofLayer: support.layer) ?? 0
            for use in support.uses where (map.rank(of: use) ?? Int.max) > rank || map.module(use) == nil {
                violations.add("support edge", "Package.swift", "\(support.target) (\(support.layer)) uses \(use)")
            }
            for file in Repository.swiftFiles(under: support.path) {
                for imported in file.imports where targets.contains(imported) && !support.uses.contains(imported) {
                    violations.add("undeclared support import", file.path, "imports \(imported)")
                }
            }
        }
        #expect(violations.isEmpty, "\(violations.report)")
    }
}
