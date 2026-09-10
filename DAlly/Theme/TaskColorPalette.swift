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

    static func swatch(hex: String) -> TaskSwatch {
        all.first { $0.hex.caseInsensitiveCompare(hex) == .orderedSame } ?? all[0]
    }
}
