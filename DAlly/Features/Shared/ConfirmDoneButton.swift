import SwiftUI

struct ConfirmDoneButton: View {
    var color: Color
    var status: DayLogStatus?
    var enabled: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .strokeBorder(color, lineWidth: 2)
                    .frame(width: 28, height: 28)
                if status == .kept {
                    Circle().fill(color).frame(width: 28, height: 28)
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(color.contrastingForeground())
                } else if status == .skipped {
                    Image(systemName: "arrow.forward.circle")
                        .font(.body)
                        .foregroundStyle(color.opacity(0.85))
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }
}
