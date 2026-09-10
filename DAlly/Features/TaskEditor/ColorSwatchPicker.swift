import SwiftUI

struct ColorSwatchPicker: View {
    @Binding var hex: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Color")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(TaskColorPalette.all) { swatch in
                        Circle()
                            .fill(swatch.color)
                            .frame(width: 32, height: 32)
                            .overlay {
                                if swatch.hex == hex {
                                    Circle().strokeBorder(Color.white, lineWidth: 3)
                                }
                            }
                            .onTapGesture { hex = swatch.hex }
                            .accessibilityLabel(swatch.name)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}
