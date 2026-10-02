import SwiftUI

struct TaskSwatch: Identifiable, Equatable {
    let index: Int
    let name: String
    let hex: String
    var id: String { hex }
    var color: Color { Color(hex: hex) }
}

enum TaskColorPalette {
    /// Spaced around the hue wheel so neighbors stay distinct in calendar dots.
    /// Never includes near-black or near-white — those are reserved for day bookmarks
    /// (black in light mode, white in dark mode).
    static let all: [TaskSwatch] = [
        .init(index: 0, name: "Ember", hex: "#FF3B30"),
        .init(index: 1, name: "Orange", hex: "#FF9500"),
        .init(index: 2, name: "Gold", hex: "#FFCC00"),
        .init(index: 3, name: "Lime", hex: "#A3E635"),
        .init(index: 4, name: "Green", hex: "#34C759"),
        .init(index: 5, name: "Mint", hex: "#00C7BE"),
        .init(index: 6, name: "Teal", hex: "#30B0C7"),
        .init(index: 7, name: "Aqua", hex: "#2CD4FF"),
        .init(index: 8, name: "Sky", hex: "#64D2FF"),
        .init(index: 9, name: "Blue", hex: "#007AFF"),
        .init(index: 10, name: "Indigo", hex: "#5856D6"),
        .init(index: 11, name: "Purple", hex: "#AF52DE"),
        .init(index: 12, name: "Orchid", hex: "#E85DFF"),
        .init(index: 13, name: "Pink", hex: "#FF2D55"),
        .init(index: 14, name: "Rose", hex: "#FF6482"),
        .init(index: 15, name: "Brown", hex: "#A2845E"),
        .init(index: 16, name: "Slate", hex: "#8E8E93"),
        .init(index: 17, name: "Navy", hex: "#1C3D5A"),
        .init(index: 18, name: "Forest", hex: "#248A3D"),
        .init(index: 19, name: "Wine", hex: "#9B1B30")
    ]

    /// Habit picker and auto-assign. Same as `all` after dropping any reserved tones.
    static var forHabits: [TaskSwatch] {
        all.filter { !isReservedForBookmarks($0.hex) }
    }

    static func swatch(hex: String) -> TaskSwatch {
        forHabits.first { $0.hex.caseInsensitiveCompare(hex) == .orderedSame }
            ?? all.first { $0.hex.caseInsensitiveCompare(hex) == .orderedSame }
            ?? forHabits[0]
    }

    /// True for pure / near black or white — bookmark calendar dots only.
    static func isReservedForBookmarks(_ hex: String) -> Bool {
        guard let rgb = rgbComponents(hex) else { return false }
        let (r, g, b) = rgb
        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        // Near-black: all channels very low.
        if maxC <= 0.12 { return true }
        // Near-white: all channels very high.
        if minC >= 0.92 { return true }
        return false
    }

    /// Snap a synced or legacy value onto a habit-safe swatch.
    static func habitSafeHex(_ hex: String) -> String {
        if !isReservedForBookmarks(hex),
           let match = forHabits.first(where: { $0.hex.caseInsensitiveCompare(hex) == .orderedSame }) {
            return match.hex
        }
        if isReservedForBookmarks(hex) {
            return forHabits[0].hex
        }
        // Unknown but not reserved (custom from an older build) — keep it.
        return hex
    }

    private static func rgbComponents(_ hex: String) -> (Double, Double, Double)? {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard cleaned.count == 6 else { return nil }
        var int: UInt64 = 0
        guard Scanner(string: cleaned).scanHexInt64(&int) else { return nil }
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        return (r, g, b)
    }
}
