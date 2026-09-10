import SwiftUI

struct DayCellView: View {
    var day: Date
    var isSelected: Bool
    var marks: DayMarks
    var cellHeight: CGFloat = 52
    @Environment(\.colorScheme) private var scheme

    private var isToday: Bool { Date.isSameLocalDay(day, Date()) }
    private var wash: Color {
        if let hex = marks.dots.first?.hex { return Color(hex: hex) }
        if marks.skipOnly { return AppColors.textTertiary(scheme) }
        return .clear
    }

    var body: some View {
        VStack(spacing: 4) {
            Text("\(Calendar.current.component(.day, from: day))")
                .font(AppTypography.primary(15, weight: isToday ? .bold : .medium))
                .foregroundStyle(isToday ? Color(hex: "#1C1C1E") : AppColors.textPrimary(scheme))
                .frame(width: 30, height: 30)
                .background {
                    if isToday {
                        Circle().fill(AppColors.aqua)
                    } else if isSelected {
                        Circle().fill(AppColors.rowFill(scheme))
                    }
                }
            marksBlock
        }
        .padding(.top, 4)
        .padding(.horizontal, 3)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .frame(height: cellHeight)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(wash.opacity(marks.dots.isEmpty ? 0.08 : (scheme == .dark ? 0.22 : 0.16)))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    isToday ? AppColors.aqua.opacity(0.9) : wash.opacity(marks.dots.isEmpty ? 0.08 : 0.35),
                    lineWidth: isToday ? 1.5 : 1
                )
        }
    }

    @ViewBuilder
    private var marksBlock: some View {
        if marks.skipOnly {
            Circle()
                .stroke(AppColors.textTertiary(scheme), lineWidth: 1)
                .frame(width: 7, height: 7)
                .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
        } else if marks.dots.isEmpty {
            Spacer(minLength: 0)
        } else {
            GeometryReader { geo in
                let layout = DotGridLayout.fit(count: marks.dots.count, in: geo.size)
                let columns = Array(
                    repeating: GridItem(.flexible(minimum: 2), spacing: layout.spacing),
                    count: layout.columns
                )
                LazyVGrid(columns: columns, alignment: .center, spacing: layout.spacing) {
                    ForEach(Array(marks.dots.enumerated()), id: \.offset) { _, dot in
                        PatternedMark(hex: dot.hex, pattern: dot.pattern, size: layout.dotSize)
                    }
                }
                .frame(width: geo.size.width, alignment: .top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

/// Packs every kept-dot into the cell by shrinking size / adding columns as needed.
private enum DotGridLayout {
    struct Result {
        var columns: Int
        var dotSize: CGFloat
        var spacing: CGFloat
    }

    static func fit(count: Int, in size: CGSize) -> Result {
        guard count > 0, size.width > 1, size.height > 1 else {
            return Result(columns: 4, dotSize: 6, spacing: 2)
        }
        let spacing: CGFloat = 2
        // Prefer fewer columns when sparse; denser grids when many marks.
        let preferredColumns = count <= 4 ? min(count, 4) : (count <= 12 ? 4 : 5)
        var best = Result(columns: preferredColumns, dotSize: 3, spacing: spacing)

        for columns in [preferredColumns, 5, 6, 4, 3] {
            let rows = Int(ceil(Double(count) / Double(columns)))
            let widthBudget = (size.width - spacing * CGFloat(columns - 1)) / CGFloat(columns)
            let heightBudget = (size.height - spacing * CGFloat(rows - 1)) / CGFloat(rows)
            let dot = min(widthBudget, heightBudget, 8)
            if dot >= best.dotSize {
                best = Result(columns: columns, dotSize: max(floor(dot * 10) / 10, 2.5), spacing: spacing)
            }
            if dot >= 4 { break }
        }
        return best
    }
}
