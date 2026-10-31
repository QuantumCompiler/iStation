import AppKit

/// Shows a Dock icon and takes focus when run from `swift run` (no .app bundle), and quits with the
/// last window.
public final class AppDelegate: NSObject, NSApplicationDelegate {
    override public init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
