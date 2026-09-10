import SwiftUI

struct SectionOpacity: ViewModifier {
    var value: Double
    func body(content: Content) -> some View {
        content.opacity(value)
    }
}

extension View {
    func sectionOpacity(_ value: Double) -> some View {
        modifier(SectionOpacity(value: value))
    }
}
