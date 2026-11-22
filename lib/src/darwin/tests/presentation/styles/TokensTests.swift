// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import CoreGraphics
import Foundation
import PresentationStyles
import Testing

/// The guardrail: every token in the design's json/tokens.json has its `styles` member with the
/// same value, and every contrast pair, recomputed from the Swift values, meets its minimum.
@Suite("styles carries the design's tokens.json")
struct TokensTests {
    let tokens: [String: Any]

    init() throws {
        tokens = try Design.tokens()
    }

    func object(_ path: String...) throws -> [String: Any] {
        var current: Any = tokens
        for key in path {
            current = try #require((current as? [String: Any])?[key], "tokens.json has no \(path.joined(separator: "."))")
        }
        return try #require(current as? [String: Any], "tokens.json's \(path.joined(separator: ".")) is not an object")
    }

    func numbers(_ path: String...) throws -> [String: Double] {
        var current: Any = tokens
        for key in path {
            current = try #require((current as? [String: Any])?[key], "tokens.json has no \(path.joined(separator: "."))")
        }
        let object = try #require(current as? [String: Any], "tokens.json's \(path.joined(separator: ".")) is not an object")
        return object.compactMapValues { ($0 as? NSNumber)?.doubleValue }
    }

    // MARK: Color

    @Test("Every color role in every theme has its Palette row, with the same value", arguments: ResolvedTheme.allCases)
    func everyColorRoleHasItsPaletteRow(theme: ResolvedTheme) throws {
        let colors = try object("color", theme.rawValue)
        let rows = Dictionary(uniqueKeysWithValues: Palette.roles.map { ($0.token, $0) })
        #expect(Set(colors.keys) == Set(rows.keys), "tokens.json's \(theme) roles and Palette.roles differ")
        for (token, value) in colors {
            let hex = try #require(value as? String, "\(theme) \(token) is not a string")
            let expected = try #require(Design.rgba(hex), "\(theme) \(token) is not a color: \(hex)")
            #expect(rows[token]?.value(in: theme) == expected, "\(theme) \(token): tokens.json \(hex), Palette \(rows[token].map { "\($0.value(in: theme))" } ?? "none")")
        }
    }

    @Test("Palette's rows name each token and member once")
    func paletteRowsAreUnique() {
        #expect(Set(Palette.roles.map(\.token)).count == Palette.roles.count)
        #expect(Set(Palette.roles.map(\.member)).count == Palette.roles.count)
    }

    @Test("tokens.json's swiftui map names each role's Palette member")
    func theSwiftUIMapNamesEachRolesMember() throws {
        let map = try object("swiftui")
        for role in Palette.roles {
            let note = try #require(map[role.token] as? String, "swiftui map has no note for \(role.token)")
            #expect(note.hasPrefix("Palette."), "swiftui map: \(role.token) names no Palette member")
            let named = note.dropFirst("Palette.".count).prefix { $0.isLetter || $0.isNumber }
            #expect(String(named) == role.member, "swiftui map: \(role.token) names Palette.\(named), Palette draws it as \(role.member)")
        }
    }

    @Test("Every contrast pair meets its minimum in every theme, recomputed from the Swift values")
    func everyContrastPairMeetsItsMinimum() throws {
        let pairs = try #require(tokens["contrastPairs"] as? [[String: Any]], "tokens.json has no contrastPairs")
        let rows = Dictionary(uniqueKeysWithValues: Palette.roles.map { ($0.token, $0) })
        var checked = 0
        for theme in ResolvedTheme.allCases {
            for pair in pairs {
                let fg = try #require(pair["fg"] as? String)
                let bg = try #require(pair["bg"] as? String)
                let minimum = try #require((pair["min"] as? NSNumber)?.doubleValue)
                let front = try #require(rows[fg], "contrast pair names \(fg), which Palette has no row for")
                let back = try #require(rows[bg], "contrast pair names \(bg), which Palette has no row for")
                let ratio = Design.contrast(front.value(in: theme), back.value(in: theme))
                #expect(ratio >= minimum, "\(theme): \(fg) on \(bg) is \(String(format: "%.2f", ratio)):1, under \(minimum):1")
                checked += 1
            }
        }
        #expect(checked == pairs.count * ResolvedTheme.allCases.count && checked > 0)
    }

    // MARK: Type

    @Test("Every text style has its macOS and iOS size")
    func everyTextStyleHasItsSizes() throws {
        let mac = try numbers("type", "mac")
        let iOS = try numbers("type", "ios")
        let styles = Dictionary(uniqueKeysWithValues: Typography.Style.allCases.map { ($0.token, $0) })
        #expect(Set(mac.keys) == Set(styles.keys), "tokens.json's type.mac and Typography.Style differ")
        #expect(Set(iOS.keys) == Set(styles.keys), "tokens.json's type.ios and Typography.Style differ")
        for (token, size) in mac {
            #expect(styles[token].map { Double($0.macSize) } == size, "type.mac.\(token)")
        }
        for (token, size) in iOS {
            #expect(styles[token].map { Double($0.iOSSize) } == size, "type.ios.\(token)")
        }
    }

    @Test("Every text size has its multiplier, and Medium is the default")
    func everyTextSizeHasItsMultiplier() throws {
        let scale = try numbers("textScale")
        let sizes = Dictionary(uniqueKeysWithValues: TextSize.allCases.map { ($0.token, $0) })
        #expect(Set(scale.keys) == Set(sizes.keys), "tokens.json's textScale and TextSize differ")
        for (token, multiplier) in scale {
            #expect(sizes[token].map { abs(Double($0.multiplier) - multiplier) < 1e-9 } == true, "textScale.\(token)")
        }
        #expect(TextSize.default.multiplier == 1)
    }

    @Test("Every weight has its value")
    func everyWeightHasItsValue() throws {
        let weights = try numbers("weight")
        let members = Dictionary(uniqueKeysWithValues: Typography.Weight.allCases.map { ($0.rawValue, $0) })
        #expect(Set(weights.keys) == Set(members.keys), "tokens.json's weight and Typography.Weight differ")
        for (name, value) in weights {
            #expect(members[name].map { Double($0.value) } == value, "weight.\(name)")
        }
    }

    @Test("A style's size follows the text size on macOS, where Dynamic Type has no say")
    func aStylesSizeFollowsTheTextSize() {
        for style in Typography.Style.allCases {
            for size in TextSize.allCases {
                let points = Typography.pointSize(style, textSize: size, dynamicTypeSize: .xxxLarge)
                #if os(macOS)
                #expect(abs(points - style.macSize * size.multiplier) < 1e-9)
                #else
                #expect(points == Typography.pointSize(style, dynamicTypeSize: .xxxLarge))
                #expect(points > style.iOSSize)
                #endif
            }
        }
    }

    // MARK: Space, radius, layout

    static let spaces: [String: CGFloat] = [
        "1": Metrics.space1, "2": Metrics.space2, "3": Metrics.space3, "4": Metrics.space4,
        "5": Metrics.space5, "6": Metrics.space6, "8": Metrics.space8, "10": Metrics.space10,
    ]

    static let radii: [String: CGFloat] = [
        "control": Metrics.radiusControl, "card": Metrics.radiusCard, "sheet": Metrics.radiusSheet,
        "window": Metrics.radiusWindow, "device": Metrics.radiusDevice, "pill": Metrics.radiusPill,
    ]

    static let layout: [String: KeyPath<LayoutSizes, CGFloat> & Sendable] = [
        "control": \.control, "toolbar": \.toolbar, "sidebar": \.sidebar, "inspector": \.inspector,
        "row": \.row, "tile": \.tile, "windowMinWidth": \.windowMinWidth, "windowMinHeight": \.windowMinHeight,
        "windowWidth": \.windowWidth, "windowHeight": \.windowHeight,
        "pictureMinWidth": \.pictureMinWidth, "pictureMinHeight": \.pictureMinHeight,
        "sheetWidth": \.sheetWidth, "alertWidth": \.alertWidth, "resultsMaxHeight": \.resultsMaxHeight,
    ]

    @Test("Every space has its Metrics member")
    func everySpaceHasItsMember() throws {
        let spaces = try numbers("space")
        #expect(Set(spaces.keys) == Set(Self.spaces.keys), "tokens.json's space and Metrics differ")
        for (key, value) in spaces {
            #expect(Self.spaces[key].map(Double.init) == value, "space.\(key)")
        }
    }

    @Test("Every radius has its Metrics member")
    func everyRadiusHasItsMember() throws {
        let radii = try numbers("radius")
        #expect(Set(radii.keys) == Set(Self.radii.keys), "tokens.json's radius and Metrics differ")
        for (key, value) in radii {
            #expect(Self.radii[key].map(Double.init) == value, "radius.\(key)")
        }
    }

    @Test("Every layout size of each platform has its Metrics member", arguments: ["mac", "ios"])
    func everyLayoutSizeHasItsMember(platform: String) throws {
        let sizes = try numbers("size", platform)
        let members = platform == "mac" ? Metrics.mac : Metrics.iOS
        #expect(Set(sizes.keys) == Set(Self.layout.keys), "tokens.json's size.\(platform) and LayoutSizes differ")
        for (key, value) in sizes {
            #expect(Self.layout[key].map { Double(members[keyPath: $0]) } == value, "size.\(platform).\(key)")
        }
    }

    // MARK: Motion

    @Test("Every duration and the ease curve have their Motion members")
    func everyDurationHasItsMember() throws {
        let motion = try object("motion")
        let durations: [String: TimeInterval] = ["fast": Motion.fast, "base": Motion.base, "slow": Motion.slow, "reduced": Motion.reduced]
        #expect(Set(motion.keys) == Set(durations.keys).union(["ease"]), "tokens.json's motion and Motion differ")
        for (key, seconds) in durations {
            let milliseconds = try #require((motion[key] as? NSNumber)?.doubleValue, "motion.\(key)")
            #expect(abs(seconds * 1000 - milliseconds) < 1e-9, "motion.\(key)")
        }
        let ease = try #require(motion["ease"] as? String)
        let inner = try #require(ease.split(separator: "(").last?.split(separator: ")").first, "motion.ease is not cubic-bezier(…): \(ease)")
        let points = inner.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        #expect(ease.hasPrefix("cubic-bezier("))
        #expect(points == [Motion.easeStart.x, Motion.easeStart.y, Motion.easeEnd.x, Motion.easeEnd.y].map(Double.init), "motion.ease: \(ease)")
    }

    @Test("Nothing animates under Reduce Motion")
    func nothingAnimatesUnderReduceMotion() {
        for duration in [Motion.fast, Motion.base, Motion.slow] {
            #expect(Motion.animation(duration, reduceMotion: true) == nil)
            #expect(Motion.animation(duration, reduceMotion: false) != nil)
        }
    }
}
