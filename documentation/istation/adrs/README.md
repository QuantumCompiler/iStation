# Architecture Decision Records — iStation

The standing rules of iStation's architecture, each written once, dated, and kept beside the reasons it exists. An ADR is **append-only history**: a changed decision is a *new* record that names the one it supersedes — never an edit that rewrites the old one. The planning system ([backlog](../backlog/README.md), [MILESTONES](../assistant/MILESTONES.md)) records *what happened when*; an ADR records *what holds now and why*.

**Format.** One file per record, named for the decision alone (`layer-enforcement.md`) — the number lives in the title and this index. Each record carries **Status** (Accepted / Superseded by NNNN), **Date**, **Context** (the evidence that forced the decision), **Decision** (the rule, stated so a change can be judged against it), **Consequences**, and **Enforcement** (where the rule is mechanical — a rule with no teeth is a suggestion).

**Relation to the layer cards.** Each layer root in the source and test trees carries a short `CLAUDE.md` card that states its layer's law and links here. Cards summarize and point; only ADRs carry rationale.

## Index

| ADR | Rule |
|---|---|
| [0001](layer-enforcement.md) | Four layers, dependencies point down, regardless of language and framework |
| [0002](module-map.md) | The module map is the layer law's one declaration |
| [0003](granular-modules.md) | One concern per module |
| [0004](tests-mirror-architecture.md) | Tests live in the layer of what they test, and never touch the real home folder |
| [0005](presentation-mvvm.md) | Presentation modules are MVVM, and share one styles module |
| [0006](presentation-previews.md) | Every Presentation module stands alone, and every view has its previews |
| [0007](backwards-compatibility.md) | ~~A library file written by an older iStation keeps loading~~ — superseded by 0016 (the library app retires; the rule carries to the new apps' data) |
| [0008](emulators-are-separate-programs.md) | ~~Emulators are separate programs, driven only by their command line; iStation ships none of their code or Sony's files~~ — superseded by 0010 |
| [0009](previews-never-carry-the-users-library.md) | Previews show the sample games, never the user's own library (supersedes ADR 0006's preview-data plan) |
| [0010](cores-are-ports-of-open-references.md) | ~~iStation's cores are Swift ports of SwanStation and PCSX2~~ — superseded by 0013 |
| [0011](each-module-carries-its-licence.md) | ~~Each module carries its licence, and never depends on a stricter one~~ — superseded by 0014 |
| [0012](cores-shape-and-hot-paths.md) | ~~A core is a CPU module and a console module (first version)~~ — superseded by 0015 |
| [0013](shipped-code-derives-only-from-permissive-references.md) | Shipped code derives only from permissive references (ProjectPSX, Play!); GPL emulators are black-box oracles; no Sony files (supersedes 0010) |
| [0014](own-code-is-mit-and-derived-code-keeps-its-notice.md) | iStation's own code is MIT; derived code keeps its reference's notice (supersedes 0011) |
| [0015](a-core-is-a-cpu-module-and-a-console-module.md) | A core is a CPU module and a console module behind one narrow interface; hot paths use concrete types (supersedes 0012) |
| [0016](two-build-routines-and-a-fresh-start.md) | Every app has an App Store routine and a personal routine; the library app is retired (supersedes 0007) |
