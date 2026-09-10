import SwiftUI

struct PatternedMark: View {
    var hex: String
    var pattern: MarkPattern
    var size: CGFloat = 8

    private var color: Color { Color(hex: hex) }

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
            patternOverlay
                .clipShape(Circle())
        }
        .frame(width: size, height: size)
        .overlay {
            if pattern == .ring {
                Circle()
                    .strokeBorder(Color.white.opacity(0.85), lineWidth: max(1, size * 0.18))
            }
        }
        .accessibilityLabel("\(TaskColorPalette.swatch(hex: hex).name) \(pattern.displayName)")
    }

    @ViewBuilder
    private var patternOverlay: some View {
        switch pattern {
        case .solid:
            EmptyView()
        case .stripes:
            StripesShape(spacing: max(2, size * 0.28))
                .stroke(Color.white.opacity(0.85), lineWidth: max(1, size * 0.14))
        case .crosshatch:
            ZStack {
                StripesShape(spacing: max(2, size * 0.3))
                    .stroke(Color.white.opacity(0.8), lineWidth: max(1, size * 0.12))
                StripesShape(spacing: max(2, size * 0.3))
                    .stroke(Color.white.opacity(0.8), lineWidth: max(1, size * 0.12))
                    .rotationEffect(.degrees(90))
            }
        case .dots:
            Canvas { context, size in
                let step = max(2.5, size.width * 0.32)
                let r = max(0.7, size.width * 0.1)
                var y: CGFloat = step * 0.45
                while y < size.height {
                    var x: CGFloat = step * 0.45
                    while x < size.width {
                        context.fill(
                            Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                            with: .color(.white.opacity(0.9))
                        )
                        x += step
                    }
                    y += step
                }
            }
        case .diagonal:
            StripesShape(spacing: max(2, size * 0.3))
                .stroke(Color.white.opacity(0.85), lineWidth: max(1, size * 0.14))
                .rotationEffect(.degrees(45))
        case .ring:
            EmptyView()
        }
    }
}

private struct StripesShape: Shape {
    var spacing: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        var x = rect.minX - rect.height
        while x < rect.maxX + rect.height {
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x + rect.height, y: rect.maxY))
            x += spacing
        }
        return path
    }
}
