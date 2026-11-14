import UIKit

/// The ONE place that decides how the app looks (colours + fonts).
/// (Translation: want a different font or colour? Change it here and the whole app follows.)
enum Theme {

    // MARK: - Colours (each has a light-mode and a dark-mode version)
    enum Colors {
        static let background = UIColor.dynamic(light: 0xFAF6EA, dark: 0x121712) // cream page
        static let card       = UIColor.dynamic(light: 0xFFFFFF, dark: 0x1C241E) // white cards
        static let sage       = UIColor.dynamic(light: 0xE6EDDB, dark: 0x243027) // soft green panels
        static let brand      = UIColor.dynamic(light: 0x2F5A3E, dark: 0x7FBF8E) // deep green buttons
        static let onBrand    = UIColor.dynamic(light: 0xFFFFFF, dark: 0x0F1A12) // text on green buttons
        static let ink        = UIColor.dynamic(light: 0x2B4A32, dark: 0xE8F0EA) // main text
        static let muted      = UIColor.dynamic(light: 0x7C8F80, dark: 0x9AAE9F) // quiet text
        static let divider    = UIColor.dynamic(light: 0xE7E0CB, dark: 0x2A332C) // thin lines
        static let chip       = UIColor.dynamic(light: 0xEFEADA, dark: 0x232C25) // unselected filter chip
        static let iconTile   = UIColor.dynamic(light: 0xEEF2E6, dark: 0x26312A) // square behind an emoji

        // Expiry status: a soft background plus a readable text colour for each.
        static let urgentBackground = UIColor.dynamic(light: 0xF8DDD6, dark: 0x4A2A24)
        static let urgentText       = UIColor.dynamic(light: 0xA4412F, dark: 0xF2A99B)
        static let soonBackground   = UIColor.dynamic(light: 0xFBE9C4, dark: 0x4A3A18)
        static let soonText         = UIColor.dynamic(light: 0x8A6012, dark: 0xF0CC7A)
        static let freshBackground  = UIColor.dynamic(light: 0xDDEBD6, dark: 0x233A2A)
        static let freshText        = UIColor.dynamic(light: 0x2F5A3E, dark: 0x9ADBA8)
    }

    // MARK: - Fonts
    /// Each "role" is a job a piece of text does. Screens ask for a ROLE, never a font name.
    /// Right now every role uses the clean sans-serif look. To make a role serif later,
    /// return `.serif` for it in `design` below - nothing else needs touching.
    enum Typography {
        case logo, screenTitle, sectionTitle, itemName, body, caption, chip, pill, button

        /// `.default` = clean sans-serif, `.serif` = book-style letters with little "feet".
        private var design: UIFontDescriptor.SystemDesign {
            switch self {
            default: return .default
            }
        }

        private var size: CGFloat {
            switch self {
            case .logo: return 30
            case .screenTitle: return 28
            case .sectionTitle: return 20
            case .itemName: return 17
            case .body: return 15
            case .caption: return 12
            case .chip: return 13
            case .pill: return 11
            case .button: return 17
            }
        }

        private var weight: UIFont.Weight {
            switch self {
            case .logo: return .bold
            case .screenTitle, .sectionTitle: return .semibold
            case .itemName, .button: return .semibold
            case .chip: return .medium
            case .pill: return .bold
            case .body, .caption: return .regular
            }
        }

        /// Which built-in text size this role grows/shrinks with when the user changes
        /// their phone's text size (accessibility).
        private var textStyle: UIFont.TextStyle {
            switch self {
            case .logo, .screenTitle: return .largeTitle
            case .sectionTitle: return .title3
            case .itemName, .button: return .headline
            case .body: return .body
            case .chip: return .footnote
            case .caption, .pill: return .caption1
            }
        }

        var font: UIFont {
            let base = UIFont.systemFont(ofSize: size, weight: weight)
            let designed = base.fontDescriptor.withDesign(design)
                .map { UIFont(descriptor: $0, size: size) } ?? base
            return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: designed)
        }
    }
}
