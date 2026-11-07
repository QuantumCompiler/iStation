#if DEBUG
import BusinessPS1

/// Player view-models for previews, over a real, powered-off console.
@MainActor
enum PreviewPlayer {
    static func nothingLoaded() -> PlayerViewModel {
        PlayerViewModel(console: PS1Console())
    }
}
#endif
