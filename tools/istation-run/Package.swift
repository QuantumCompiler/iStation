// swift-tools-version: 6.0
// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors
import PackageDescription

// A personal tool, outside the iStation package: runs the Swift PS1 console with TraceKit recording,
// writes the CPU-check program, and diffs traces (v0.0.1 items 3d and 3g). Nothing here ships.
let package = Package(
    name: "istation-run",
    platforms: [.macOS(.v14)],
    dependencies: [.package(path: "../../src/istation")],
    targets: [
        .executableTarget(
            name: "istation-run",
            dependencies: [.product(name: "PS1Core", package: "istation"), .product(name: "TraceKit", package: "istation")],
            path: "Sources"
        ),
    ]
)
