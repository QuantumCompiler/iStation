// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import CoreGraphics
import PresentationStyles

/// The library window's layout at a width, as the design's Layout page sets its breakpoints: under
/// `sidebarWithInfoMinWidth` (1,100 points) of window, Game info hides the sidebar; under
/// `formatColumnMinWidth` (880) of content beside them, the table's Format column goes, and under
/// `lastPlayedColumnMinWidth` (700) its Last played column. At 800 × 560, the window's least
/// (`Mac-LibraryMin`), 580 points are left beside the sidebar, and the table keeps Name, Console, Serial
/// and Size. Pure, so the view asks it with the width it measures and the tests pin each breakpoint.
public struct LibraryLayout: Sendable, Equatable {
    /// A column of the library's table, in its order.
    public enum Column: String, Sendable, CaseIterable, Identifiable {
        case name, console, serial, format, size, lastPlayed

        /// The column's heading, as the design writes it.
        public var title: String {
            switch self {
            case .name: "Name"
            case .console: "Console"
            case .serial: "Serial"
            case .format: "Format"
            case .size: "Size"
            case .lastPlayed: "Last played"
            }
        }

        /// The column itself.
        public var id: Self { self }
    }

    /// Whether the sidebar shows.
    public var showsSidebar: Bool
    /// Whether Game info shows.
    public var showsInfo: Bool
    /// The width left for the table or grid, beside the sidebar and Game info.
    public var contentWidth: CGFloat
    /// The table's columns at that width, in order.
    public var columns: [Column]

    /// The layout of a window `windowWidth` wide, its sidebar shown if `wantsSidebar` (the person's ⌃⌘S)
    /// unless Game info, shown if `showsInfo`, leaves it too little room, in `sizes`.
    public init(windowWidth: CGFloat, wantsSidebar: Bool, showsInfo: Bool, sizes: LayoutSizes = Metrics.layout) {
        let showsSidebar = wantsSidebar && !(showsInfo && windowWidth < sizes.sidebarWithInfoMinWidth)
        let content = windowWidth - (showsSidebar ? sizes.sidebar : 0) - (showsInfo ? sizes.inspector : 0)
        self.showsSidebar = showsSidebar
        self.showsInfo = showsInfo
        contentWidth = content
        columns = Self.columns(contentWidth: content, sizes: sizes)
    }

    /// The table's columns in content `contentWidth` wide: every one from `formatColumnMinWidth`; without
    /// Format under it; without Last played too under `lastPlayedColumnMinWidth`.
    public static func columns(contentWidth: CGFloat, sizes: LayoutSizes = Metrics.layout) -> [Column] {
        Column.allCases.filter { column in
            switch column {
            case .format: contentWidth >= sizes.formatColumnMinWidth
            case .lastPlayed: contentWidth >= sizes.lastPlayedColumnMinWidth
            case .name, .console, .serial, .size: true
            }
        }
    }
}
