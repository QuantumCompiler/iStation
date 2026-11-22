// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

/// The status a chip, a banner, a job's summary or an alert is drawn in. Each tone is a pair of the
/// design's color roles, a text color on its fill, that tokens.json holds to 4.5:1 in every theme. A
/// view-model names the tone and the view draws it, so no color reaches a view-model.
public enum Tone: String, Sendable, CaseIterable {
    /// Plain words on a control's fill: a console's or a licence's chip.
    case neutral
    /// Quieter words on a control's fill: Plays later.
    case muted
    /// Something worked: Running, a BIOS that reached its shell.
    case ok
    /// Something needs attention: Paused, File missing, a job that was stopped.
    case warning
    /// Something failed: a BIOS of the wrong size, a disc that couldn't be read.
    case danger
    /// Something to know: what this version can't do yet.
    case info
    /// Not yet checked against the real console or backend: the Personal build chip.
    case verify

    /// The tone's text and symbol color, as tokens.json names the role.
    public var foregroundToken: String {
        switch self {
        case .neutral: "fg"
        case .muted: "fg-muted"
        case .ok: "ok"
        case .warning: "warn"
        case .danger: "danger"
        case .info: "info"
        case .verify: "verify"
        }
    }

    /// The tone's fill, as tokens.json names the role.
    public var fillToken: String {
        switch self {
        case .neutral, .muted: "bg-control"
        case .ok: "ok-bg"
        case .warning: "warn-bg"
        case .danger: "danger-bg"
        case .info: "info-bg"
        case .verify: "verify-bg"
        }
    }

    /// The SF Symbol a banner or an alert in this tone leads with, as the design draws them: a check
    /// for success, a triangle for a warning, a crossed circle for a failure, and the information
    /// circle for the rest.
    public var symbol: String {
        switch self {
        case .ok: Symbols.done
        case .warning: Symbols.warning
        case .danger: Symbols.failed
        case .neutral, .muted, .info, .verify: Symbols.info
        }
    }
}
