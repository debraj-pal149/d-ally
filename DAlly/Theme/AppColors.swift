import SwiftUI

enum AppColors {
    static func bgPrimary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "#121214") : Color(hex: "#F2F2F7")
    }

    static func bgElevated(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "#1C1C1E") : Color(hex: "#FFFFFF")
    }

    static func bgGrouped(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "#2C2C2E") : Color(hex: "#FFFFFF")
    }

    static func separator(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "#3A3A3C") : Color(hex: "#C6C6C8")
    }

    static func textPrimary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "#F2F2F7") : Color(hex: "#1C1C1E")
    }

    static func textSecondary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "#A1A1A6") : Color(hex: "#6C6C70")
    }

    static func textTertiary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "#6C6C70") : Color(hex: "#8E8E93")
    }

    static func danger(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "#FF453A") : Color(hex: "#FF3B30")
    }

    static func success(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "#30D158") : Color(hex: "#34C759")
    }

    static let aqua = Color(hex: "#2CD4FF")
    static let warning = Color(hex: "#FFB020")

    /// Aqua that stays readable as text on light surfaces.
    static func aquaInk(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "#5EE1FF") : Color(hex: "#0A6F88")
    }

    static func coolGlass(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "#2CD4FF").opacity(0.07) : Color(hex: "#2CD4FF").opacity(0.08)
    }

    static func rowFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04)
    }

    static func canvasGradient(_ scheme: ColorScheme) -> LinearGradient {
        if scheme == .dark {
            return LinearGradient(
                colors: [Color(hex: "#15202A"), Color(hex: "#12161C"), Color(hex: "#0C1014")],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        return LinearGradient(
            colors: [Color(hex: "#E8F6FC"), Color(hex: "#F2F5F7"), Color(hex: "#E8EEF2")],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

struct AppCanvas: View {
    var accent: Color = AppColors.aqua
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            AppColors.canvasGradient(scheme)
            RadialGradient(
                colors: [
                    accent.opacity(scheme == .dark ? 0.48 : 0.34),
                    accent.opacity(scheme == .dark ? 0.16 : 0.12),
                    Color.clear
                ],
                center: UnitPoint(x: 0.92, y: 0.02),
                startRadius: 8,
                endRadius: 520
            )
            RadialGradient(
                colors: [
                    accent.opacity(scheme == .dark ? 0.32 : 0.22),
                    Color.clear
                ],
                center: UnitPoint(x: 0.22, y: 0.08),
                startRadius: 4,
                endRadius: 360
            )
            RadialGradient(
                colors: [
                    accent.opacity(scheme == .dark ? 0.18 : 0.12),
                    Color.clear
                ],
                center: UnitPoint(x: 0.5, y: 1.05),
                startRadius: 20,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }
}

struct BrandWordmark: View {
    var size: CGFloat = 22
    var weight: Font.Weight = .bold
    var color: Color = .primary
    var dotColor: Color = AppColors.aqua

    private var dotSize: CGFloat { max(10, size * 0.42) }
    /// Optical: sit the aqua disc a hair below the letter midline.
    private var dotNudgeY: CGFloat { max(1.2, size * 0.055) }

    var body: some View {
        HStack(alignment: .center, spacing: max(7, size * 0.2)) {
            Text("d")
            Circle()
                .fill(dotColor)
                .frame(width: dotSize, height: dotSize)
                .shadow(color: dotColor.opacity(0.55), radius: max(3, size * 0.12))
                .offset(y: dotNudgeY)
            Text("ally")
        }
        .font(AppTypography.primary(size, weight: weight))
        .foregroundStyle(color)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AppCopy.brand)
        .accessibilityAddTraits(.isHeader)
    }
}

struct BrandMark: View {
    var compact: Bool = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            BrandWordmark(
                size: compact ? 18 : 24,
                weight: .bold,
                color: AppColors.textPrimary(scheme)
            )
            if !compact {
                Text(AppCopy.tagline)
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.aquaInk(scheme))
            }
        }
    }
}
