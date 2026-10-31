// swift-tools-version: 6.0
import PackageDescription

// MARK: - The module map (ADR 0002)
//
// The layer law's one declaration. Each `Module` row is one module: its layer, its name, and the
// modules it may import, by target name. A row becomes a library target `<Layer><Name>` built from
// source/<layer>/<name in lowercase>/, and a test target `<Layer><Name>Tests` built from
// tests/<layer>/<name in lowercase>/ that may also use the shared fixtures listed in `testSupport:`.
//
// ArchitectureTests (tests/architecture/) parses these rows: keep each row on one line, in this form.
// A new module is a new row here, its two directories, its name on its layer's CLAUDE.md card and a
// row in documentation/istation/adrs/module-map.md, all in the same change.

enum Layer: String, CaseIterable { case infrastructure, data, business, presentation }

let modules: [Module] = [
    Module(.infrastructure, "Bytes"),
    Module(.infrastructure, "Locations"),
    Module(.infrastructure, "Bundles", testSupport: ["SupportSandbox"]),
    Module(.infrastructure, "Process"),

    Module(.data, "Catalog"),
    Module(.data, "ISO9660", uses: ["InfrastructureBytes"], testSupport: ["SupportSandbox", "SupportDiscFixtures"]),
    Module(.data, "SystemCNF", uses: ["DataCatalog"]),
    Module(.data, "ParamSFO", uses: ["InfrastructureBytes"], testSupport: ["SupportDiscFixtures"]),
    Module(.data, "Playlists", testSupport: ["SupportSandbox"]),
    Module(.data, "Emulators", uses: ["DataCatalog"]),
    Module(.data, "Store", uses: ["DataCatalog", "DataEmulators"], testSupport: ["SupportSandbox"]),

    Module(.business, "Identification", uses: ["DataCatalog", "DataISO9660", "DataParamSFO", "DataPlaylists", "DataSystemCNF"], testSupport: ["SupportSandbox", "SupportDiscFixtures"]),
    Module(.business, "Scanning", uses: ["BusinessIdentification", "DataCatalog", "DataParamSFO", "DataPlaylists"], testSupport: ["SupportSandbox", "SupportDiscFixtures"]),
    Module(.business, "Discovery", uses: ["DataEmulators", "InfrastructureBundles", "InfrastructureLocations"], testSupport: ["SupportSandbox"]),
    Module(.business, "Launching", uses: ["DataCatalog", "DataEmulators", "InfrastructureBundles", "InfrastructureProcess"], testSupport: ["SupportSandbox"]),
    Module(.business, "Library", uses: ["BusinessDiscovery", "BusinessIdentification", "BusinessLaunching", "BusinessScanning", "DataCatalog", "DataEmulators", "DataStore"], testSupport: ["SupportLibraryFakes"]),

    Module(.presentation, "Styles", uses: ["DataCatalog"]),
    Module(.presentation, "Shell", uses: ["BusinessLibrary", "DataCatalog", "DataEmulators", "DataStore", "PresentationStyles"], testSupport: ["SupportLibraryFakes"]),
    Module(.presentation, "Library", uses: ["BusinessLibrary", "DataCatalog", "DataEmulators", "DataStore", "PresentationStyles"], testSupport: ["SupportLibraryFakes"]),
    Module(.presentation, "Settings", uses: ["BusinessLibrary", "DataCatalog", "DataEmulators", "DataStore", "PresentationStyles"], testSupport: ["SupportLibraryFakes"]),
    Module(.presentation, "App", uses: ["BusinessDiscovery", "BusinessLaunching", "BusinessLibrary", "BusinessScanning", "DataEmulators", "DataStore", "InfrastructureBundles", "InfrastructureLocations", "InfrastructureProcess", "PresentationLibrary", "PresentationSettings", "PresentationShell", "PresentationStyles"], testSupport: ["SupportSandbox"]),
]

/// Shared test fixtures and fakes, each at the lowest layer whose tests use it (ADR 0004).
/// A row becomes a library target `Support<Name>` built from tests/support/<name in lowercase>/.
let testSupport: [Support] = [
    Support(.infrastructure, "Sandbox"),
    Support(.data, "DiscFixtures"),
    Support(.business, "LibraryFakes", uses: ["BusinessLibrary", "DataCatalog", "DataEmulators", "DataStore"]),
]

/// The `@main` entry point: it starts PresentationApp with the real user's folders and holds no logic.
/// It is not a module, and nothing imports it.
let entryPoint = EntryPoint("iStation", uses: ["InfrastructureLocations", "PresentationApp"])

// MARK: - Targets, generated from the map

struct Module {
    let layer: Layer
    let name: String
    let uses: [String]
    let testSupport: [String]

    init(_ layer: Layer, _ name: String, uses: [String] = [], testSupport: [String] = []) {
        self.layer = layer
        self.name = name
        self.uses = uses
        self.testSupport = testSupport
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

struct EntryPoint {
    let name: String
    let uses: [String]

    init(_ name: String, uses: [String]) {
        self.name = name
        self.uses = uses
    }
}

func dependencies(_ names: [String]) -> [Target.Dependency] {
    names.map { .target(name: $0) }
}

let package = Package(
    name: "iStation",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: entryPoint.name, targets: [entryPoint.name]),
    ],
    targets: modules.flatMap { module -> [Target] in
        [
            .target(name: module.target, dependencies: dependencies(module.uses), path: module.path),
            .testTarget(
                name: module.target + "Tests",
                dependencies: dependencies([module.target] + module.testSupport),
                path: module.testPath
            ),
        ]
    } + testSupport.map { support in
        .target(name: support.target, dependencies: dependencies(support.uses), path: support.path)
    } + [
        .executableTarget(name: entryPoint.name, dependencies: dependencies(entryPoint.uses), path: "source/main"),
        // The layering and layer-context checks (ADRs 0001, 0002, 0004, 0005, 0008). Reads files only.
        .testTarget(name: "ArchitectureTests", path: "tests/architecture"),
    ]
)
