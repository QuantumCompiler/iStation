import Foundation

/// The user's standard folders, held as one value so the whole app can be pointed at a sandbox.
///
/// `user()` is the only way to the real home folder, and only the entry point calls it; tests and
/// previews build theirs with `sandbox(root:)`.
public struct Locations: Equatable, Sendable {
    public var home: URL
    /// ~/Library/Application Support
    public var applicationSupport: URL
    /// Folders searched for installed apps, in order.
    public var applications: [URL]

    public init(home: URL, applicationSupport: URL, applications: [URL]) {
        self.home = home
        self.applicationSupport = applicationSupport
        self.applications = applications
    }

    /// The real folders of the user running the app.
    public static func user() -> Locations {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        return Locations(
            home: home,
            applicationSupport: fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0],
            applications: [URL(fileURLWithPath: "/Applications"), home.appendingPathComponent("Applications")]
        )
    }

    /// A home folder at `root`, laid out like a real one. Nothing is created on disk.
    public static func sandbox(root: URL) -> Locations {
        Locations(
            home: root,
            applicationSupport: root.appendingPathComponent("Library/Application Support"),
            applications: [root.appendingPathComponent("Applications")]
        )
    }
}
