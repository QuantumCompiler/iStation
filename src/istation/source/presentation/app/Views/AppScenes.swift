import PresentationSettings
import PresentationShell
import SwiftUI

/// The app's scenes: the main window with its menu commands, and the Settings window (⌘,).
public struct AppScenes: Scene {
    private let model: AppViewModel

    public init(model: AppViewModel) {
        self.model = model
    }

    public var body: some Scene {
        WindowGroup("iStation") {
            MainWindow(model: model)
        }
        .commands {
            ShellCommands(viewModel: model.shell)
        }

        Settings {
            SettingsView(viewModel: model.settings)
        }
    }
}
