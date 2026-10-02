import Foundation

enum ColorAssignmentService {
    struct Assignment: Equatable {
        var colorHex: String
        var pattern: MarkPattern
    }

    static func nextUnused(existing: [DailyTask]) -> Assignment {
        let used = Set(existing.map { key(hex: $0.colorHex, pattern: $0.markPatternKind) })
        let palette = TaskColorPalette.forHabits
        for pattern in MarkPattern.allCases {
            for swatch in palette {
                let candidate = key(hex: swatch.hex, pattern: pattern)
                if !used.contains(candidate) {
                    return Assignment(colorHex: swatch.hex, pattern: pattern)
                }
            }
        }
        let fallback = palette[existing.count % palette.count]
        return Assignment(colorHex: fallback.hex, pattern: .solid)
    }

    /// Compatibility for call sites that only need a hex.
    static func nextUnusedHex(existing: [DailyTask]) -> String {
        nextUnused(existing: existing).colorHex
    }

    private static func key(hex: String, pattern: MarkPattern) -> String {
        "\(hex.uppercased())|\(pattern.rawValue)"
    }
}
