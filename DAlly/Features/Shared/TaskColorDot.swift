import SwiftUI

struct TaskColorDot: View {
    var hex: String
    var pattern: MarkPattern = .solid
    var size: CGFloat = 12

    var body: some View {
        PatternedMark(hex: hex, pattern: pattern, size: size)
    }
}
