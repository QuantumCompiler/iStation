// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import CoreGraphics

/// Every size and spacing the apps lay out with, named for its role.
public enum Metrics {
    /// A PS1 screen's shape on a 4:3 television.
    public static let screenAspectRatio: CGFloat = 4.0 / 3.0
    public static let playerMinWidth: CGFloat = 640
    public static let playerMinHeight: CGFloat = 480
    public static let contentPadding: CGFloat = 24
    public static let stackSpacing: CGFloat = 12
}
