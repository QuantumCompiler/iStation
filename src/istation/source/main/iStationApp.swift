import InfrastructureLocations
import PresentationApp
import SwiftUI

/// The entry point: starts the composition over the real user's folders. Holds no logic.
@main
struct iStationApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppViewModel(locations: .user())

    var body: some Scene {
        AppScenes(model: model)
    }
}
