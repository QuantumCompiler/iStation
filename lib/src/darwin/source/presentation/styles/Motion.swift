// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import SwiftUI

/// Every duration and curve the apps animate with (tokens.json's `motion`), and none under Reduce Motion.
public enum Motion {
    /// A hover, a press, a toggle: 120 ms.
    public static let fast: TimeInterval = 0.120
    /// A sheet, a disclosure, a selection: 200 ms.
    public static let base: TimeInterval = 0.200
    /// A view changing place: 320 ms.
    public static let slow: TimeInterval = 0.320
    /// The duration under Reduce Motion: nothing moves.
    public static let reduced: TimeInterval = 0

    /// The ease curve's first control point, from `cubic-bezier(0.2, 0, 0, 1)`.
    public static let easeStart = UnitPoint(x: 0.2, y: 0)
    /// The ease curve's second control point.
    public static let easeEnd = UnitPoint(x: 0, y: 1)
    /// The ease every animation follows: quick to start, gentle to land.
    public static let ease: UnitCurve = .bezier(startControlPoint: easeStart, endControlPoint: easeEnd)

    /// The animation for a duration, or none when Reduce Motion is on: pass the view's
    /// `accessibilityReduceMotion`.
    public static func animation(_ duration: TimeInterval, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .timingCurve(ease, duration: duration)
    }
}
