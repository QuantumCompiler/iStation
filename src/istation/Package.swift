// swift-tools-version: 6.0
import PackageDescription

// MARK: - The module map (ADR 0002)
//
// The layer law's one declaration. Each `Module` row is one module: its layer, its name, and the
// modules it may import, by target name. A row becomes a library target `<Layer><Name>` built from
// source/<layer>/<name in lowercase>/, and a test target `<Layer><Name>Tests` built from
// tests/<layer>/<name in lowercase>/ that may also use the shared fixtures listed in `testSupport:`.
// `derivedFrom:` names the permissive reference a module is ported from (ADRs 0013, 0014): every file in
// it then carries that reference's notice and a provenance line; omitted, the module is iStation's own.
//
// ArchitectureTests (tests/architecture/) parses these rows: keep each row on one line, in this form.
// A new module is a new row here, its two directories, its name on its layer's CLAUDE.md card and a
// row in documentation/istation/adrs/module-map.md, all in the same change.

enum Layer: String, CaseIterable { case infrastructure, data, business, presentation }

/// Where a module's code comes from: iStation's own, ProjectPSX (MIT, PS1) or Play! (BSD-2-Clause, PS2).
enum Derivation: String { case none, projectPSX, play }

let modules: [Module] = [
    Module(.infrastructure, "Bytes"),

    Module(.data, "ISO9660", uses: ["InfrastructureBytes"], testSupport: ["SupportSandbox", "SupportDiscFixtures"]),
    Module(.data, "SystemCNF"),
    Module(.data, "Playlists", testSupport: ["SupportSandbox"]),
    Module(.data, "Tracing", testSupport: ["SupportSandbox"]),

    Module(.business, "R3000A", testSupport: ["SupportR3000ATrace", "SupportSandbox"], derivedFrom: .projectPSX),
    Module(.business, "PS1"),

    Module(.presentation, "Styles"),
    Module(.presentation, "Player", uses: ["BusinessPS1", "PresentationStyles"]),
    Module(.presentation, "Acknowledgements", uses: ["PresentationStyles"]),
]

/// Shared test fixtures and fakes, each at the lowest layer whose tests use it (ADR 0004).
/// A row becomes a library target `Support<Name>` built from tests/support/<name in lowercase>/.
let testSupport: [Support] = [
    Support(.infrastructure, "Sandbox"),
    Support(.data, "DiscFixtures"),
    Support(.business, "R3000ATrace", uses: ["BusinessR3000A", "DataTracing"]),
]

/// The library products the apps in iStation.xcodeproj link (ADR 0016). The apps are the entry
/// points: nothing in the package is an executable, and nothing imports an app.
let products: [Product] = [
    .library(name: "PS1Core", targets: ["BusinessR3000A", "BusinessPS1"]),
    .library(name: "EmuKit", targets: ["PresentationStyles", "PresentationPlayer", "PresentationAcknowledgements"]),
    // Personal builds only: no app links it in its App Store routine (ADR 0016).
    .library(name: "TraceKit", targets: ["DataTracing"]),
]

/// `PERSONAL_BUILD` guards every tool and debug view (ADR 0016). The personal routine builds the
/// package in its debug configuration, the App Store routine in release, so release code never sees it.
let settings: [SwiftSetting] = [.define("PERSONAL_BUILD", .when(configuration: .debug))]

// MARK: - Targets, generated from the map

struct Module {
    let layer: Layer
    let name: String
    let uses: [String]
    let testSupport: [String]
    let derivedFrom: Derivation

    init(_ layer: Layer, _ name: String, uses: [String] = [], testSupport: [String] = [], derivedFrom: Derivation = .none) {
        self.layer = layer
        self.name = name
        self.uses = uses
        self.testSupport = testSupport
        self.derivedFrom = derivedFrom
    }

    var target: String { layer.rawValue.prefix(1).uppercased() + layer.rawValue.dropFirst() + name }
    var path: String { "source/\(layer.rawValue)/\(name.lowercased())" }
    var testPath: String { "tests/\(layer.rawValue)/\(name.lowercased())" }
}

struct Support {
    let layer: Layer
    let name: String
    let uses: [String]

    init(_ layer: Layer, _ name: String, uses: [String] = []) {
        self.layer = layer
        self.name = name
        self.uses = uses
    }

    var target: String { "Support" + name }
    var path: String { "tests/support/\(name.lowercased())" }
}

func dependencies(_ names: [String]) -> [Target.Dependency] {
    names.map { .target(name: $0) }
}

let package = Package(
    name: "iStation",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: products,
    targets: modules.flatMap { module -> [Target] in
        [
            .target(name: module.target, dependencies: dependencies(module.uses), path: module.path, swiftSettings: settings),
            .testTarget(
                name: module.target + "Tests",
                dependencies: dependencies([module.target] + module.testSupport),
                path: module.testPath,
                swiftSettings: settings
            ),
        ]
    } + testSupport.map { support in
        .target(name: support.target, dependencies: dependencies(support.uses), path: support.path, swiftSettings: settings)
    } + [
        // The layering, layer-context and project-rule checks (ADRs 0001, 0002, 0004, 0005, 0013, 0016). Reads files only.
        .testTarget(name: "ArchitectureTests", path: "tests/architecture"),
    ]
)
