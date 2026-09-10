import Foundation
import SwiftUI

struct DayBoundaryObserver: ViewModifier {
    var onDayChange: () -> Void
    @State private var lastKey = Date().localDayKey

    func body(content: Content) -> some View {
        content
            .background {
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    Color.clear
                        .onChange(of: context.date.localDayKey) { _, new in
                            if new != lastKey {
                                lastKey = new
                                onDayChange()
                            }
                        }
                }
            }
    }
}

extension View {
    func onLocalDayChange(_ action: @escaping () -> Void) -> some View {
        modifier(DayBoundaryObserver(onDayChange: action))
    }
}
