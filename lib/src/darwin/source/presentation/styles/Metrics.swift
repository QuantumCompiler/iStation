// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import CoreGraphics

/// The sizes one platform lays its windows and controls out with (tokens.json's `size.mac` and `size.ios`).
public struct LayoutSizes: Sendable, Equatable {
    /// A control's height: a button, a field, a segmented control.
    public let control: CGFloat
    /// The window's toolbar height.
    public let toolbar: CGFloat
    /// The sidebar's width.
    public let sidebar: CGFloat
    /// The inspector's width.
    public let inspector: CGFloat
    /// A list row's height.
    public let row: CGFloat
    /// A grid tile's width.
    public let tile: CGFloat
    /// The width of the smallest window the layout is drawn for.
    public let windowMinWidth: CGFloat
    /// The height of the smallest window the layout is drawn for.
    public let windowMinHeight: CGFloat
    /// The window's width when it first opens.
    public let windowWidth: CGFloat
    /// The window's height when it first opens.
    public let windowHeight: CGFloat
    /// The narrowest the console's picture is drawn.
    public let pictureMinWidth: CGFloat
    /// The shortest the console's picture is drawn.
    public let pictureMinHeight: CGFloat
    /// A sheet's width, such as the job sheet's. On iOS a sheet spans the screen, so size.ios gives the
    /// iPhone's width the design draws it at, and the iOS sheet takes the screen's width instead.
    public let sheetWidth: CGFloat
    /// An alert's width, such as the Details alert's.
    public let alertWidth: CGFloat
    /// The tallest a sheet's list of results grows before it scrolls.
    public let resultsMaxHeight: CGFloat
    /// The first run's column of text, Welcome's. On iOS a screen's column spans the screen, so size.ios
    /// gives the iPhone's width the design draws it at.
    public let welcomeWidth: CGFloat
    /// The widest a pane's content grows, its inset included, as the BIOS pane's does. On iOS, the
    /// iPhone's width, as `welcomeWidth` is.
    public let paneMaxWidth: CGFloat
    /// The narrowest content beside the sidebar and Game info that keeps the library's Format column, as
    /// the Layout page's breakpoints have it: under it the column goes.
    public let formatColumnMinWidth: CGFloat
    /// The narrowest content that keeps the library's Last played column: under it the column goes.
    public let lastPlayedColumnMinWidth: CGFloat
    /// The narrowest window that keeps the sidebar while Game info shows: under it Game info hides the
    /// sidebar. On iOS, where the library is a list, the breakpoints are the Mac's and never apply.
    public let sidebarWithInfoMinWidth: CGFloat
    /// The least the library table's Name column narrows to; it takes the width the others leave.
    public let nameColumn: CGFloat
    /// The library table's Console column.
    public let consoleColumn: CGFloat
    /// The library table's Serial column.
    public let serialColumn: CGFloat
    /// The library table's Format column.
    public let formatColumn: CGFloat
    /// The library table's Size column.
    public let sizeColumn: CGFloat
    /// The library table's Last played column. On iOS, where the library is a list, the table's columns
    /// are the Mac's and never apply.
    public let lastPlayedColumn: CGFloat
    /// The height of Game info's box of initials, in place of artwork.
    public let infoArtHeight: CGFloat
    /// The width of Game info's column of fact names: Console, Serial, Format… On iOS, Game info's sizes
    /// are the Mac's and never apply.
    public let factNameWidth: CGFloat
    /// The empty library's column of text, "Add your games". On iOS, the iPhone's width, as `welcomeWidth` is.
    public let emptyWidth: CGFloat
    /// The narrowest the library's games get: no wider than the least window holds beside the sidebar —
    /// which the split view counts twice once Game info can show beside the games (measured) — and Game
    /// info together, as the split view shows the two for a moment when the window narrows with Game info
    /// open or Game info closes under the breakpoint. The games' height doesn't follow their text, so the
    /// split view measuring them this narrow asks the window for no height. On iOS, the least iPhone's width.
    public let gamesMinWidth: CGFloat

    /// A platform's sizes as tokens.json gives them.
    public init(
        control: CGFloat, toolbar: CGFloat, sidebar: CGFloat, inspector: CGFloat, row: CGFloat, tile: CGFloat,
        windowMinWidth: CGFloat, windowMinHeight: CGFloat, windowWidth: CGFloat, windowHeight: CGFloat,
        pictureMinWidth: CGFloat, pictureMinHeight: CGFloat,
        sheetWidth: CGFloat, alertWidth: CGFloat, resultsMaxHeight: CGFloat,
        welcomeWidth: CGFloat, paneMaxWidth: CGFloat,
        formatColumnMinWidth: CGFloat, lastPlayedColumnMinWidth: CGFloat, sidebarWithInfoMinWidth: CGFloat,
        nameColumn: CGFloat, consoleColumn: CGFloat, serialColumn: CGFloat, formatColumn: CGFloat, sizeColumn: CGFloat,
        lastPlayedColumn: CGFloat, infoArtHeight: CGFloat, factNameWidth: CGFloat, emptyWidth: CGFloat,
        gamesMinWidth: CGFloat
    ) {
        self.control = control
        self.toolbar = toolbar
        self.sidebar = sidebar
        self.inspector = inspector
        self.row = row
        self.tile = tile
        self.windowMinWidth = windowMinWidth
        self.windowMinHeight = windowMinHeight
        self.windowWidth = windowWidth
        self.windowHeight = windowHeight
        self.pictureMinWidth = pictureMinWidth
        self.pictureMinHeight = pictureMinHeight
        self.sheetWidth = sheetWidth
        self.alertWidth = alertWidth
        self.resultsMaxHeight = resultsMaxHeight
        self.welcomeWidth = welcomeWidth
        self.paneMaxWidth = paneMaxWidth
        self.formatColumnMinWidth = formatColumnMinWidth
        self.lastPlayedColumnMinWidth = lastPlayedColumnMinWidth
        self.sidebarWithInfoMinWidth = sidebarWithInfoMinWidth
        self.nameColumn = nameColumn
        self.consoleColumn = consoleColumn
        self.serialColumn = serialColumn
        self.formatColumn = formatColumn
        self.sizeColumn = sizeColumn
        self.lastPlayedColumn = lastPlayedColumn
        self.infoArtHeight = infoArtHeight
        self.factNameWidth = factNameWidth
        self.emptyWidth = emptyWidth
        self.gamesMinWidth = gamesMinWidth
    }
}

/// Every size and spacing the apps lay out with, named for its role.
public enum Metrics {
    // MARK: Spacing (tokens.json's `space`)

    /// 4 pt (space.1): the smallest gap.
    public static let space1: CGFloat = 4
    /// 8 pt (space.2).
    public static let space2: CGFloat = 8
    /// 12 pt (space.3): the space between stacked items.
    public static let space3: CGFloat = 12
    /// 16 pt (space.4).
    public static let space4: CGFloat = 16
    /// 20 pt (space.5): a sheet's and an alert's inset.
    public static let space5: CGFloat = 20
    /// 24 pt (space.6): the space around a screen's content.
    public static let space6: CGFloat = 24
    /// 32 pt (space.8).
    public static let space8: CGFloat = 32
    /// 40 pt (space.10): the largest gap.
    public static let space10: CGFloat = 40

    // MARK: Corner radii (tokens.json's `radius`)

    /// A button's, field's or chip's corners.
    public static let radiusControl: CGFloat = 6
    /// A card's or tile's corners.
    public static let radiusCard: CGFloat = 10
    /// A sheet's corners.
    public static let radiusSheet: CGFloat = 12
    /// A window's corners, as the design draws them.
    public static let radiusWindow: CGFloat = 12
    /// An iPhone's screen corners, as the design draws them.
    public static let radiusDevice: CGFloat = 44
    /// Fully round ends, for pills and badges.
    public static let radiusPill: CGFloat = 999

    // MARK: Layout (tokens.json's `size`)

    /// The macOS app's layout sizes.
    public static let mac = LayoutSizes(
        control: 28, toolbar: 52, sidebar: 220, inspector: 300, row: 30, tile: 168,
        windowMinWidth: 800, windowMinHeight: 560, windowWidth: 1280, windowHeight: 800,
        pictureMinWidth: 640, pictureMinHeight: 480,
        sheetWidth: 520, alertWidth: 320, resultsMaxHeight: 220,
        welcomeWidth: 460, paneMaxWidth: 720,
        formatColumnMinWidth: 880, lastPlayedColumnMinWidth: 700, sidebarWithInfoMinWidth: 1100,
        nameColumn: 180, consoleColumn: 72, serialColumn: 104, formatColumn: 120, sizeColumn: 80,
        lastPlayedColumn: 130, infoArtHeight: 140, factNameWidth: 96, emptyWidth: 440, gamesMinWidth: 60
    )

    /// The iOS app's layout sizes.
    public static let iOS = LayoutSizes(
        control: 44, toolbar: 52, sidebar: 320, inspector: 320, row: 64, tile: 160,
        windowMinWidth: 320, windowMinHeight: 568, windowWidth: 390, windowHeight: 844,
        pictureMinWidth: 320, pictureMinHeight: 240,
        sheetWidth: 390, alertWidth: 290, resultsMaxHeight: 220,
        welcomeWidth: 390, paneMaxWidth: 390,
        formatColumnMinWidth: 880, lastPlayedColumnMinWidth: 700, sidebarWithInfoMinWidth: 1100,
        nameColumn: 180, consoleColumn: 72, serialColumn: 104, formatColumn: 120, sizeColumn: 80,
        lastPlayedColumn: 130, infoArtHeight: 140, factNameWidth: 96, emptyWidth: 390, gamesMinWidth: 320
    )

    /// This platform's layout sizes.
    public static var layout: LayoutSizes {
        #if os(macOS)
        mac
        #else
        iOS
        #endif
    }

    // MARK: The player and acknowledgements

    /// A PS1 screen's shape on a 4:3 television.
    public static let screenAspectRatio: CGFloat = 4.0 / 3.0
    /// The player's narrowest picture on macOS.
    public static let playerMinWidth: CGFloat = mac.pictureMinWidth
    /// The player's shortest picture on macOS.
    public static let playerMinHeight: CGFloat = mac.pictureMinHeight
    /// The space around a screen's content.
    public static let contentPadding: CGFloat = space6
    /// The space between stacked items.
    public static let stackSpacing: CGFloat = space3
}
