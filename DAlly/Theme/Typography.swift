import SwiftUI

enum AppTypography {
    /// Primary: Sora — wordmark, titles, reminder names.
    static func primary(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom(soraName(for: weight), size: size)
    }

    /// Secondary: Figtree — times, notes, captions, body UI.
    static func secondary(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom(figtreeName(for: weight), size: size)
    }

    static let brand = primary(34, weight: .bold)
    static let screenTitle = primary(20, weight: .semibold)
    static let sectionHeader = secondary(12, weight: .semibold)
    static let taskName = primary(17, weight: .medium)
    static let time = secondary(12, weight: .medium)
    static let notes = secondary(12, weight: .regular)
    static let emptyTitle = primary(20, weight: .semibold)
    static let body = secondary(15, weight: .regular)
    static let callout = secondary(16, weight: .medium)
    static let subheadline = secondary(15, weight: .regular)
    static let footnote = secondary(13, weight: .regular)
    static let caption = secondary(12, weight: .regular)
    static let captionSemibold = secondary(12, weight: .semibold)
    static let button = secondary(15, weight: .semibold)
    static let heroTitle = primary(28, weight: .bold)
    static let heroTime = primary(20, weight: .semibold)

    private static func soraName(for weight: Font.Weight) -> String {
        switch weight {
        case .bold, .heavy, .black: return "Sora-Bold"
        case .semibold: return "Sora-SemiBold"
        case .medium: return "Sora-Medium"
        default: return "Sora-Regular"
        }
    }

    private static func figtreeName(for weight: Font.Weight) -> String {
        switch weight {
        case .bold, .heavy, .black: return "Figtree-Bold"
        case .semibold: return "Figtree-SemiBold"
        case .medium: return "Figtree-Medium"
        default: return "Figtree-Regular"
        }
    }
}
