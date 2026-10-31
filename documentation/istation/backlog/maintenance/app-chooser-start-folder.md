# The emulator chooser opens in /Applications again

**What / why.** The scaffold's `LibraryModel.chooseApp(for:)` opened an `NSOpenPanel` at `/Applications`. The port moved choosers to SwiftUI's `.fileImporter` so the view-model stays AppKit-free ([ADR 0005](../../adrs/presentation-mvvm.md)); `.fileImporter` has no starting folder on macOS 14, so Settings' Choose… (`src/istation/source/presentation/settings/Views/SettingsView.swift`, the `.applicationBundle` importer) now opens wherever the system last left it. A behavior the port changed, recorded at construction, 2026-10-31.

**Core constraint(s).** View-models import no UI toolkit (⚠ in CLAUDE.md); no literal path or size in a feature view ([ADR 0005](../../adrs/presentation-mvvm.md)). The folder comes from `Locations.applications`, not a literal: the real folders are known only to the composition root.

**Seam + files.** Presentation `settings`: `SettingsViewModel` exposes the folder the chooser starts in, passed in by `app` from `Locations.applications.first`; `SettingsView` applies it with SwiftUI's default-directory modifier where the OS has it. Presentation `app`: `AppViewModel` passes the folder. Tests: `tests/presentation/settings/SettingsViewModelTests.swift`, `tests/presentation/app/AppViewModelTests.swift`.

**Decisions made** (dated):
- 2026-10-31: queued as Maintenance, found while porting the scaffold (construction).

**Open calls:**
- [default: use SwiftUI's `fileDialogDefaultDirectory(_:)` under `if #available(macOS 15, *)` (verify the modifier's availability against the SDK first), and accept the system default on macOS 14 rather than adding an AppKit panel back] How to set the starting folder.

**Guardrail(s).** A view-model test asserts the chooser's starting folder is the first applications folder of the `Locations` it was built over (a `Sandbox` in the test).

**Acceptance criteria:**
- [ ] On macOS 15 and later, Settings → Emulators → Choose… opens in /Applications.
- [ ] No view-model imports SwiftUI or AppKit; no literal path appears in a view.

**Scope note.** Maintenance, polish; claimable any time; no gate. Out of scope: the folder choosers' starting folder.
