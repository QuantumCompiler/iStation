// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import SwiftUI
#if !os(macOS)
import UIKit
#endif

/// The text-size setting: four sizes, each a multiplier on every macOS text style (tokens.json's
/// `textScale`); on iOS text follows Dynamic Type instead. Settings holds it; a view reads it
/// through the environment.
public enum TextSize: String, Codable, Sendable, CaseIterable {
    /// Small: 0.92 times each style's size.
    case small
    /// Medium: each style at its own size. The default.
    case medium
    /// Large: 1.12 times each style's size.
    case large
    /// Extra large: 1.25 times each style's size.
    case extraLarge

    /// The setting a person starts with, and the one an unreadable stored value falls back to.
    public static let `default`: TextSize = .medium

    /// The size's name in tokens.json's `textScale`.
    public var token: String {
        switch self {
        case .small: "s"
        case .medium: "m"
        case .large: "l"
        case .extraLarge: "xl"
        }
    }

    /// What every text style's size is multiplied by.
    public var multiplier: CGFloat {
        switch self {
        case .small: 0.92
        case .medium: 1
        case .large: 1.12
        case .extraLarge: 1.25
        }
    }

    /// The size's name in Settings.
    public var name: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        case .extraLarge: "Extra large"
        }
    }

    /// Reads a stored size, falling back to the default on a value this version doesn't know.
    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = TextSize(rawValue: raw) ?? .default
    }
}

/// Every font the apps set text in, named for its role: the design's text styles at their macOS and
/// iOS sizes, scaled on macOS by the text-size setting and on iOS by Dynamic Type.
public enum Typography {
    /// A text style of the design (tokens.json's `type.mac` and `type.ios`).
    public enum Style: String, Sendable, CaseIterable {
        /// The largest title.
        case largeTitle
        /// The second-largest title.
        case title
        /// The third-largest title.
        case title2
        /// The smallest title, such as a job sheet's.
        case title3
        /// A heading at the body size, set heavier.
        case headline
        /// Running text and labels.
        case body
        /// Text that explains, a step smaller than the body.
        case callout
        /// The smallest text, such as a chip's or a keycap's.
        case caption

        /// The style's name in tokens.json.
        public var token: String { rawValue.lowercased() }

        /// The style's size on macOS, in points, at the Medium text size.
        public var macSize: CGFloat {
            switch self {
            case .largeTitle: 26
            case .title: 20
            case .title2: 17
            case .title3: 15
            case .headline: 13
            case .body: 13
            case .callout: 12
            case .caption: 11
            }
        }

        /// The style's size on iOS, in points, at the Medium text size and the default Dynamic Type size.
        public var iOSSize: CGFloat {
            switch self {
            case .largeTitle: 34
            case .title: 28
            case .title2: 22
            case .title3: 20
            case .headline: 17
            case .body: 17
            case .callout: 16
            case .caption: 13
            }
        }

        /// The style's size on this platform, at the Medium text size.
        public var size: CGFloat {
            #if os(macOS)
            macSize
            #else
            iOSSize
            #endif
        }

        /// The weight the design sets the style in unless a view asks for another (the Foundations-Type board).
        public var weight: Weight {
            switch self {
            case .largeTitle, .title: .bold
            case .title2, .title3, .headline: .semibold
            case .body, .callout, .caption: .regular
            }
        }

        /// The system text style whose Dynamic Type scaling this style follows on iOS.
        public var dynamicTypeStyle: Font.TextStyle {
            switch self {
            case .largeTitle: .largeTitle
            case .title: .title
            case .title2: .title2
            case .title3: .title3
            case .headline: .headline
            case .body: .body
            case .callout: .callout
            case .caption: .caption
            }
        }
    }

    /// A weight of the design (tokens.json's `weight`).
    public enum Weight: String, Sendable, CaseIterable {
        /// 400.
        case regular
        /// 500.
        case medium
        /// 600.
        case semibold
        /// 700.
        case bold

        /// The weight as tokens.json writes it, a CSS weight.
        public var value: Int {
            switch self {
            case .regular: 400
            case .medium: 500
            case .semibold: 600
            case .bold: 700
            }
        }

        /// The weight as SwiftUI sets it.
        public var fontWeight: Font.Weight {
            switch self {
            case .regular: .regular
            case .medium: .medium
            case .semibold: .semibold
            case .bold: .bold
            }
        }
    }

    /// A style's size in points. On macOS, which has no Dynamic Type, it is the style's size times the
    /// text-size setting; on iOS it is the style's size scaled by Dynamic Type as its matching system
    /// text style scales, and the text-size setting is not used (the design: text follows the iPhone).
    public static func pointSize(_ style: Style, textSize: TextSize = .default, dynamicTypeSize: DynamicTypeSize = .large) -> CGFloat {
        #if os(macOS)
        return style.macSize * textSize.multiplier
        #else
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dynamicTypeSize))
        return UIFontMetrics(forTextStyle: style.uiTextStyle).scaledValue(for: style.iOSSize, compatibleWith: traits)
        #endif
    }

    /// A style as a font, in its own weight unless one is given, monospaced when asked.
    public static func font(_ style: Style, textSize: TextSize = .default, dynamicTypeSize: DynamicTypeSize = .large, weight: Weight? = nil, monospaced: Bool = false) -> Font {
        .system(size: pointSize(style, textSize: textSize, dynamicTypeSize: dynamicTypeSize), weight: (weight ?? style.weight).fontWeight, design: monospaced ? .monospaced : .default)
    }

    // MARK: Fonts the player and acknowledgements set today

    /// A screen's or entry's title.
    public static let title = Font.title2.weight(.semibold)
    /// Running text.
    public static let body = Font.body
    /// Monospaced running text: paths, serials, commands, at the body size. To follow the text size,
    /// use `.textStyle(.body, monospaced: true)`.
    public static let mono = font(.body, monospaced: true)
    /// The large symbol on an empty screen.
    public static let screenSymbol = Font.system(size: 48)
}

#if !os(macOS)
extension Typography.Style {
    var uiTextStyle: UIFont.TextStyle {
        switch self {
        case .largeTitle: .largeTitle
        case .title: .title1
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .body: .body
        case .callout: .callout
        case .caption: .caption1
        }
    }
}
#endif

private struct TextSizeKey: EnvironmentKey {
    static let defaultValue: TextSize = .default
}

extension EnvironmentValues {
    /// The text-size setting the views below draw at on macOS; the apps set it from Settings.
    public var textSize: TextSize {
        get { self[TextSizeKey.self] }
        set { self[TextSizeKey.self] = newValue }
    }
}

private struct TextStyleModifier: ViewModifier {
    let style: Typography.Style
    let weight: Typography.Weight?
    let monospaced: Bool
    @Environment(\.textSize) private var textSize
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        content.font(Typography.font(style, textSize: textSize, dynamicTypeSize: dynamicTypeSize, weight: weight, monospaced: monospaced))
    }
}

extension View {
    /// Sets text in one of the design's styles, at the current text size on macOS and the current
    /// Dynamic Type size on iOS, in the style's own weight unless one is given.
    public func textStyle(_ style: Typography.Style, weight: Typography.Weight? = nil, monospaced: Bool = false) -> some View {
        modifier(TextStyleModifier(style: style, weight: weight, monospaced: monospaced))
    }
}
