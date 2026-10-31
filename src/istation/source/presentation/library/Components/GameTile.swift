import PresentationStyles
import SwiftUI

/// One game: a placeholder case in its console's color with the title, the console badge, and the
/// serial and play time underneath. Outlined while the game is running.
struct GameTile: View {
    let model: GameTileModel

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.tileSpacing) {
            ZStack(alignment: .topTrailing) {
                // Placeholder "case" until cover art is added.
                RoundedRectangle(cornerRadius: Metrics.tileCornerRadius)
                    .fill(Palette.tint(for: model.platform).gradient)
                    .aspectRatio(Metrics.coverAspectRatio, contentMode: .fit)
                    .overlay {
                        Text(model.title)
                            .font(Typography.coverTitle)
                            .foregroundStyle(Palette.onTint)
                            .multilineTextAlignment(.center)
                            .shadow(radius: Metrics.coverTitleShadow)
                            .padding(Metrics.coverTitlePadding)
                    }
                Text(model.platform.shortName)
                    .font(Typography.badge)
                    .padding(.horizontal, Metrics.badgeHorizontalPadding)
                    .padding(.vertical, Metrics.badgeVerticalPadding)
                    .background(Palette.badgeBackground, in: Capsule())
                    .foregroundStyle(Palette.onTint)
                    .padding(Metrics.badgeInset)
            }
            .overlay {
                if model.isRunning {
                    RoundedRectangle(cornerRadius: Metrics.tileCornerRadius)
                        .strokeBorder(Palette.running, lineWidth: Metrics.runningOutlineWidth)
                }
            }

            Text(model.title)
                .font(Typography.tileTitle)
                .lineLimit(2)
            HStack(spacing: Metrics.detailSpacing) {
                if model.isRunning {
                    Label("Playing", systemImage: Symbols.playing).foregroundStyle(Palette.running)
                } else {
                    Text(model.detail)
                }
            }
            .font(Typography.tileDetail)
            .foregroundStyle(Palette.secondaryText)
            .lineLimit(1)
        }
        .contentShape(Rectangle())
        .help(model.location.path)
    }
}

#if DEBUG
#Preview("Played") {
    GameTile(model: GameTileModel(game: PreviewLibrary.recorded.games[0], isRunning: false))
        .frame(width: Metrics.tileMaxWidth)
}

#Preview("Never played") {
    GameTile(model: GameTileModel(game: PreviewLibrary.recorded.games[1], isRunning: false))
        .frame(width: Metrics.tileMaxWidth)
}

#Preview("Playing") {
    GameTile(model: GameTileModel(game: PreviewLibrary.recorded.games[2], isRunning: true))
        .frame(width: Metrics.tileMaxWidth)
}
#endif
