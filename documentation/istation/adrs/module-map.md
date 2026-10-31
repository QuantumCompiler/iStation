# ADR 0002 — The module map is the layer law's one declaration

**Status:** Accepted · **Date:** 2026-10-31

## Context

[ADR 0001](layer-enforcement.md) fixes the layers and the rule between them. A law stated in prose and again in the build drifts the first time one of them changes; the build and every check must read one declaration.

## Decision

**The `modules` table at the top of `src/istation/Package.swift` is the one declaration of which module sits in which layer and which modules it may depend on, and this table restates it.** Each `Module(.<layer>, "<Name>", uses: […], testSupport: […])` row generates the library target `<Layer><Name>` from `source/<layer>/<name>/` and the test target `<Layer><Name>Tests` from `tests/<layer>/<name>/`. Within the layer bound, a module may depend on exactly the targets its row lists. Shared test fixtures are `Support(.<layer>, "<Name>")` rows (target `Support<Name>`, `tests/support/<name>/`), placed at the lowest layer whose tests use them. The entry point's own imports are its `entryPoint` row.

The directory naming follows SwiftPM's freedom of `path:`: lowercase module directories, `<Layer><Name>` target names (the default, taken 2026-10-31).

| Layer | Module | May depend on |
|---|---|---|
| infrastructure | `bytes` | — |
| infrastructure | `locations` | — |
| infrastructure | `bundles` | — |
| infrastructure | `process` | — |
| data | `catalog` | — |
| data | `iso9660` | `InfrastructureBytes` |
| data | `systemcnf` | `DataCatalog` |
| data | `paramsfo` | `InfrastructureBytes` |
| data | `playlists` | — |
| data | `emulators` | `DataCatalog` |
| data | `store` | `DataCatalog`, `DataEmulators` |
| business | `identification` | `DataCatalog`, `DataISO9660`, `DataParamSFO`, `DataPlaylists`, `DataSystemCNF` |
| business | `scanning` | `BusinessIdentification`, `DataCatalog`, `DataParamSFO`, `DataPlaylists` |
| business | `discovery` | `DataEmulators`, `InfrastructureBundles`, `InfrastructureLocations` |
| business | `launching` | `DataCatalog`, `DataEmulators`, `InfrastructureBundles`, `InfrastructureProcess` |
| business | `library` | `BusinessDiscovery`, `BusinessIdentification`, `BusinessLaunching`, `BusinessScanning`, `DataCatalog`, `DataEmulators`, `DataStore` |
| presentation | `styles` | `DataCatalog` |
| presentation | `shell` | `BusinessLibrary`, `DataCatalog`, `DataEmulators`, `DataStore`, `PresentationStyles` |
| presentation | `library` | `BusinessLibrary`, `DataCatalog`, `DataEmulators`, `DataStore`, `PresentationStyles` |
| presentation | `settings` | `BusinessLibrary`, `DataCatalog`, `DataEmulators`, `DataStore`, `PresentationStyles` |
| presentation | `app` | `BusinessDiscovery`, `BusinessLaunching`, `BusinessLibrary`, `BusinessScanning`, `DataEmulators`, `DataStore`, `InfrastructureBundles`, `InfrastructureLocations`, `InfrastructureProcess`, `PresentationLibrary`, `PresentationSettings`, `PresentationShell`, `PresentationStyles` |

The Presentation feature modules' `DataEmulators` and `DataStore` edges serve their preview fakes, which conform to `Library`'s service protocols.

## Consequences

- A new module is a row in the map, a row in this table, a name on its layer card, and its source and test directories — in the same change; any one alone fails the check below.
- A module moving layers is a new record superseding this one; the table is history at the date it holds.

## Enforcement

`ArchitectureTests/LayerContextTests.swift` holds this table, the layer cards' **Modules** lines and the mirrored test tree equal to the map, and fails when it cannot find them. `ArchitectureTests/LayeringTests.swift` holds the code to the map ([ADR 0001](layer-enforcement.md)). Both verified against planted violations, 2026-10-31.
