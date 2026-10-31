import CoreServices
import Foundation

/// Finds where an installed app lives, by bundle identifier.
public protocol AppLookup: Sendable {
    func installedApp(bundleIdentifier: String) -> URL?
}

/// Launch Services' answer: the apps the system knows for that identifier, best first.
public struct LaunchServicesLookup: AppLookup {
    public init() {}

    public func installedApp(bundleIdentifier: String) -> URL? {
        let urls = LSCopyApplicationURLsForBundleIdentifier(bundleIdentifier as CFString, nil)?.takeRetainedValue()
        return (urls as? [URL])?.first
    }
}

/// Reading `.app` bundles on disk.
public enum AppBundles {
    /// The binary inside an .app bundle, e.g. PCSX2.app/Contents/MacOS/PCSX2.
    public static func executable(inAppBundle app: URL) -> URL? {
        if let url = Bundle(url: app)?.executableURL { return url }
        let macOS = app.appendingPathComponent("Contents/MacOS")
        let contents = (try? FileManager.default.contentsOfDirectory(at: macOS, includingPropertiesForKeys: nil)) ?? []
        return contents.first
    }

    /// The first `<folder>/<name>` that exists, trying each folder in order and each name within it.
    public static func firstApp(named names: [String], in folders: [URL]) -> URL? {
        let fileManager = FileManager.default
        for folder in folders {
            for name in names {
                let candidate = folder.appendingPathComponent(name)
                if fileManager.fileExists(atPath: candidate.path) { return candidate }
            }
        }
        return nil
    }
}
