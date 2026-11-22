// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

/// One icon the design draws: its key in the design's `ICON` set (`html/main.html`), the `Symbols`
/// member that stands for it, and the SF Symbol drawn in its place.
public struct SymbolEntry: Sendable, Hashable {
    /// The icon's key in the design's `ICON` set, e.g. `folderPlus`.
    public let icon: String
    /// The `Symbols` member, e.g. `addFolder`.
    public let member: String
    /// The SF Symbol's name, e.g. `folder.badge.plus`.
    public let name: String

    /// An icon and the symbol drawn for it.
    public init(_ icon: String, _ member: String, _ name: String) {
        self.icon = icon
        self.member = member
        self.name = name
    }
}

/// SF Symbol names, named for what they stand for. Every one is available from macOS 14 and iOS 17.
public enum Symbols {
    // MARK: The player and acknowledgements

    /// An empty player.
    public static let nothingToPlay = "gamecontroller"
    /// The acknowledgements screen.
    public static let acknowledgements = "doc.text"

    // MARK: Adding and the library

    /// Add games, or a new memory card (`plus`).
    public static let add = "plus"
    /// A folder (`folder`).
    public static let folder = "folder"
    /// Add a folder of games (`folderPlus`).
    public static let addFolder = "folder.badge.plus"
    /// Every game in the library (`stack`).
    public static let allGames = "square.stack"
    /// A disc, and a console's games (`disc`).
    public static let disc = "opticaldisc"
    /// A PS-EXE program file (`exe`).
    public static let program = "doc.badge.gearshape"
    /// Any other file (`doc`).
    public static let document = "doc"
    /// Recently played games (`clock`).
    public static let recentlyPlayed = "clock"
    /// A memory card (`card`).
    public static let memoryCard = "sdcard"
    /// The BIOS (`chip`).
    public static let bios = "memorychip"
    /// The personal build's tools, and the debug drawer (`tools`).
    public static let tools = "wrench.and.screwdriver"
    /// Show the games as a list (`list`).
    public static let listView = "list.bullet"
    /// Show the games as a grid (`grid`).
    public static let gridView = "square.grid.2x2"
    /// Show or hide the sidebar (`sidebar`).
    public static let sidebar = "sidebar.left"
    /// A game's info, the inspector (`info`).
    public static let info = "info.circle"
    /// Search (`search`).
    public static let search = "magnifyingglass"
    /// Rename (`pencil`).
    public static let rename = "pencil"
    /// Delete (`trash`).
    public static let delete = "trash"
    /// Copy, such as a command (`copy`).
    public static let copy = "doc.on.doc"
    /// Find a file that moved (`locate`).
    public static let locate = "mappin.and.ellipse"
    /// Show a file in the Finder (`finder`).
    public static let showInFinder = "folder.circle"
    /// Open a link outside the app (`external`).
    public static let openExternally = "arrow.up.right.square"

    // MARK: The player

    /// Play or resume (`play`).
    public static let play = "play.fill"
    /// Pause (`pause`).
    public static let pause = "pause.fill"
    /// Stop (`stop`).
    public static let stop = "stop.fill"
    /// Reset the console (`reset`).
    public static let reset = "arrow.counterclockwise"
    /// Save a state (`save`).
    public static let saveState = "tray.and.arrow.down"
    /// Load a state (`load`).
    public static let loadState = "tray.and.arrow.up"
    /// Save a screenshot (`camera`).
    public static let screenshot = "camera"
    /// Enter or leave full screen (`fullscreen`).
    public static let fullScreen = "arrow.up.left.and.arrow.down.right"

    // MARK: Navigation

    /// Back, and stop and go back to the library (`chevronLeft`).
    public static let back = "chevron.left"
    /// Go into a row (`chevronRight`).
    public static let forward = "chevron.right"
    /// Close or dismiss (`x`).
    public static let close = "xmark"

    // MARK: Steps and outcomes

    /// A chosen option (`check`).
    public static let checked = "checkmark"
    /// A step that finished, an outcome that worked (`checkCircle`).
    public static let done = "checkmark.circle"
    /// A warning (`warn`).
    public static let warning = "exclamationmark.triangle"
    /// A step or outcome that failed (`error`).
    public static let failed = "xmark.circle"
    /// A step that was stopped (`stopCircle`).
    public static let stopped = "stop.circle"
    /// A step not yet started, or skipped (`pending`).
    public static let pending = "circle"
    /// A step that is running (`spinner`).
    public static let running = "circle.dashed"

    // MARK: Settings

    /// Settings (`gear`).
    public static let settings = "gearshape"
    /// Controllers (`gamepad`).
    public static let controller = "gamecontroller"
    /// The keyboard as a controller (`keyboard`).
    public static let keyboard = "keyboard"
    /// Video settings (`display`).
    public static let video = "display"
    /// Audio settings (`sound`).
    public static let audio = "speaker.wave.2"
    /// Appearance settings (`palette`).
    public static let appearance = "paintpalette"
    /// A person (`person`).
    public static let person = "person"

    // MARK: The on-screen pad

    /// The pad's up button (`up`).
    public static let padUp = "arrow.up"
    /// The pad's down button (`down`).
    public static let padDown = "arrow.down"
    /// The pad's left button (`left`).
    public static let padLeft = "arrow.left"
    /// The pad's right button (`right`).
    public static let padRight = "arrow.right"
    /// The triangle face button (`shapeTriangle`).
    public static let triangleButton = "triangle"
    /// The circle face button (`shapeCircle`).
    public static let circleButton = "circle"
    /// The cross face button (`shapeCross`).
    public static let crossButton = "xmark"
    /// The square face button (`shapeSquare`).
    public static let squareButton = "square"

    /// Every icon of the design's `ICON` set, in its order, with the member that stands for it. The
    /// symbols test checks it against `html/main.html` and that each symbol exists.
    public static let icons: [SymbolEntry] = [
        SymbolEntry("plus", "add", add),
        SymbolEntry("folder", "folder", folder),
        SymbolEntry("folderPlus", "addFolder", addFolder),
        SymbolEntry("play", "play", play),
        SymbolEntry("pause", "pause", pause),
        SymbolEntry("stop", "stop", stop),
        SymbolEntry("reset", "reset", reset),
        SymbolEntry("save", "saveState", saveState),
        SymbolEntry("load", "loadState", loadState),
        SymbolEntry("camera", "screenshot", screenshot),
        SymbolEntry("fullscreen", "fullScreen", fullScreen),
        SymbolEntry("sidebar", "sidebar", sidebar),
        SymbolEntry("list", "listView", listView),
        SymbolEntry("grid", "gridView", gridView),
        SymbolEntry("info", "info", info),
        SymbolEntry("search", "search", search),
        SymbolEntry("chevronLeft", "back", back),
        SymbolEntry("chevronRight", "forward", forward),
        SymbolEntry("check", "checked", checked),
        SymbolEntry("checkCircle", "done", done),
        SymbolEntry("warn", "warning", warning),
        SymbolEntry("error", "failed", failed),
        SymbolEntry("stopCircle", "stopped", stopped),
        SymbolEntry("pending", "pending", pending),
        SymbolEntry("spinner", "running", running),
        SymbolEntry("x", "close", close),
        SymbolEntry("disc", "disc", disc),
        SymbolEntry("stack", "allGames", allGames),
        SymbolEntry("exe", "program", program),
        SymbolEntry("doc", "document", document),
        SymbolEntry("card", "memoryCard", memoryCard),
        SymbolEntry("chip", "bios", bios),
        SymbolEntry("gamepad", "controller", controller),
        SymbolEntry("keyboard", "keyboard", keyboard),
        SymbolEntry("gear", "settings", settings),
        SymbolEntry("clock", "recentlyPlayed", recentlyPlayed),
        SymbolEntry("tools", "tools", tools),
        SymbolEntry("sound", "audio", audio),
        SymbolEntry("display", "video", video),
        SymbolEntry("palette", "appearance", appearance),
        SymbolEntry("person", "person", person),
        SymbolEntry("trash", "delete", delete),
        SymbolEntry("pencil", "rename", rename),
        SymbolEntry("external", "openExternally", openExternally),
        SymbolEntry("locate", "locate", locate),
        SymbolEntry("finder", "showInFinder", showInFinder),
        SymbolEntry("copy", "copy", copy),
        SymbolEntry("up", "padUp", padUp),
        SymbolEntry("down", "padDown", padDown),
        SymbolEntry("left", "padLeft", padLeft),
        SymbolEntry("right", "padRight", padRight),
        SymbolEntry("shapeTriangle", "triangleButton", triangleButton),
        SymbolEntry("shapeCircle", "circleButton", circleButton),
        SymbolEntry("shapeCross", "crossButton", crossButton),
        SymbolEntry("shapeSquare", "squareButton", squareButton),
    ]
}
