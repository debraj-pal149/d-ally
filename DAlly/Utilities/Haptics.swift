import UIKit

enum Haptics {
    static func markDone() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func skip() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    static func undo() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func delete() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func dayChange() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
}
