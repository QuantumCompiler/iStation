# Architecture Decision Records — iStation

The standing rules of iStation's architecture, each written once, dated, and kept beside the reasons it exists. An ADR is **append-only history**: a changed decision is a *new* record that names the one it supersedes — never an edit that rewrites the old one. The planning system ([backlog](../../backlog/darwin/README.md), [MILESTONES](../../assistant/darwin/MILESTONES.md)) records *what happened when*; an ADR records *what holds now and why*.

**Format.** One file per record, named for the decision alone (`layer-enforcement.md`) — the number lives in the title and this index. Each record carries **Status** (Accepted / Superseded by NNNN), **Date**, **Context** (the evidence that forced the decision), **Decision** (the rule, stated so a change can be judged against it), **Consequences**, and **Enforcement** (where the rule is mechanical — a rule with no teeth is a suggestion).

**Relation to the layer cards.** Each layer root in the source and test trees carries a short `CLAUDE.md` card that states its layer's law and links here. Cards summarize and point; only ADRs carry rationale.

## Index

| ADR | Rule |
|---|---|
| [0001](layer-enforcement.md) | ~~Four layers, dependencies point down, regardless of language and framework~~ — superseded by 0018 (the rule stands, restated for today's modules, apps and checks after the library app's retirement) |
| [0002](module-map.md) | The module map is the layer law's one declaration |
| [0003](granular-modules.md) | One concern per module |
| [0004](tests-mirror-architecture.md) | ~~Tests live in the layer of what they test, and never touch the real home folder~~ — superseded by 0019 (the library app's retirement left it naming modules and checks that no longer exist; the rule carries) |
| [0005](presentation-mvvm.md) | ~~Presentation modules are MVVM, and share one styles module~~ — superseded by 0020 (its modules retired with the library app; the rule carries to today's) |
| [0006](presentation-previews.md) | ~~Every Presentation module stands alone, and every view has its previews~~ — superseded by 0021 (restated for today's modules after the library app's retirement) |
| [0007](backwards-compatibility.md) | ~~A library file written by an older iStation keeps loading~~ — superseded by 0016 (the library app retires; the rule carries to the new apps' data) |
| [0008](emulators-are-separate-programs.md) | ~~Emulators are separate programs, driven only by their command line; iStation ships none of their code or Sony's files~~ — superseded by 0010 |
| [0009](previews-never-carry-the-users-library.md) | ~~Previews show the sample games, never the user's own library (supersedes ADR 0006's preview-data plan)~~ — superseded by 0021 (the sample games retired with the library app; the rule carries to the user's BIOS images and games) |
| [0010](cores-are-ports-of-open-references.md) | ~~iStation's cores are Swift ports of SwanStation and PCSX2~~ — superseded by 0013 |
| [0011](each-module-carries-its-licence.md) | ~~Each module carries its licence, and never depends on a stricter one~~ — superseded by 0014 |
| [0012](cores-shape-and-hot-paths.md) | ~~A core is a CPU module and a console module (first version)~~ — superseded by 0015 |
| [0013](shipped-code-derives-only-from-permissive-references.md) | Shipped code derives only from permissive references (ProjectPSX, Play!); GPL emulators are black-box oracles; no Sony files (supersedes 0010) |
| [0014](own-code-is-mit-and-derived-code-keeps-its-notice.md) | iStation's own code is MIT; derived code keeps its reference's notice (supersedes 0011) |
| [0015](a-core-is-a-cpu-module-and-a-console-module.md) | A core is a CPU module and a console module behind one narrow interface; hot paths use concrete types (supersedes 0012) |
| [0016](two-build-routines-and-a-fresh-start.md) | Every app has an App Store routine and a personal routine; the library app is retired (supersedes 0007) |
| [0017](every-presentation-module-has-its-scheme.md) | Every Presentation module has its own shared Xcode scheme, which builds it and tests it alone |
| [0018](four-layers-dependencies-point-down.md) | Four layers, dependencies point down, regardless of language and framework (supersedes 0001) |
| [0019](tests-live-in-the-layer-of-what-they-test.md) | Tests live in the layer of what they test and never touch the real home folder; `macOS Personal` tests every test target (supersedes 0004) |
| [0020](presentation-is-mvvm-with-one-styles-module.md) | ~~Presentation modules are MVVM and share one styles module; the apps are the composition roots (supersedes 0005)~~ — superseded by 0023 (`styles` carries the design's own colors from its `tokens.json`, in three themes, and the theme setting, where it named SwiftUI's own; the rule otherwise carries) |
| [0021](presentation-modules-stand-alone-and-preview-sample-data.md) | Every Presentation module stands alone; its views preview each visible state over sample data; nothing derived from the user's files is committed (supersedes 0006, 0009) |
| [0022](nothing-starts-a-process-or-loads-code-at-runtime.md) | Nothing in the package or the apps starts a process or loads code at runtime; code a core generates into a `MAP_JIT` region is not loaded code (carries the process rule of 0008 and 0010, which 0013 left out) |
| [0023](presentation-is-mvvm-and-styles-carries-the-design.md) | Presentation modules are MVVM and share one styles module, which carries the design's tokens in three themes, the theme setting and the shared components; the apps are the composition roots (supersedes 0020) |
