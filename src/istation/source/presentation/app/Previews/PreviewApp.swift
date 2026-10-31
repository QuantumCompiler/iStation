#if DEBUG
import Foundation
import InfrastructureBundles
import InfrastructureLocations
import InfrastructureProcess

/// The real composition over a fresh temporary home: no real user folders, no processes, and no
/// Launch Services lookups.
@MainActor
enum PreviewApp {
    static func firstLaunch() -> AppViewModel {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("iStationPreview-\(UUID().uuidString)")
        return AppViewModel(locations: .sandbox(root: root), runner: PreviewRunner(), lookup: PreviewLookup())
    }
}

struct PreviewRunner: ProcessRunning {
    func run(_ command: Command, onExit: @escaping @Sendable (ProcessExit) -> Void) throws {}
}

struct PreviewLookup: AppLookup {
    func installedApp(bundleIdentifier: String) -> URL? { nil }
}
#endif
