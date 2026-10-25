import SwiftUI

struct WelcomeView: View {
    @AppStorage(AppStorageKey.welcomeSeen) private var welcomeSeen = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#1A1A1E"), Color(hex: "#121214"), Color(hex: "#0C0C0E")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    BrandWordmark(
                        size: 34,
                        weight: .bold,
                        color: Color(hex: "#F2F2F7")
                    )
                Text(AppCopy.tagline)
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.aqua)
                    .padding(.top, 6)

                Text(AppCopy.welcomeBody)
                    .font(AppTypography.subheadline)
                    .foregroundStyle(Color(hex: "#A1A1A6"))
                    .lineLimit(1)
                    .padding(.top, 18)

                    VStack(alignment: .leading, spacing: 14) {
                        welcomePoint(color: Color(hex: "#2CD4FF"), text: AppCopy.point1)
                        welcomePoint(color: Color(hex: "#2EE6A6"), text: AppCopy.point2)
                        welcomePoint(color: Color(hex: "#FF6B4A"), text: AppCopy.point3)

                        welcomeBookmarkPoint
                            .padding(.top, 12)
                    }
                    .padding(.top, 28)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.horizontal, 28)

                Button(action: begin) {
                    Text(AppCopy.begin)
                        .font(AppTypography.button)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(Color(hex: "#1C1C1E"))
                }
                .background(AppColors.aqua, in: Capsule())
                .padding(.horizontal, 28)

                Button(AppCopy.alreadyKnow, action: begin)
                    .font(AppTypography.footnote)
                    .foregroundStyle(Color(hex: "#A1A1A6"))
                    .padding(.top, 12)
                    .padding(.bottom, 28)
            }
        }
        .preferredColorScheme(.dark)
        .accessibilityElement(children: .contain)
    }

    private var welcomeBookmarkPoint: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "bookmark.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(hex: "#F2F2F7"))
                .frame(width: 10, height: 14)
            Text(AppCopy.pointBookmark)
                .font(AppTypography.subheadline)
                .foregroundStyle(Color(hex: "#F2F2F7"))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func welcomePoint(color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle().fill(color).frame(width: 10, height: 10)
                .padding(.top, 4)
            Text(text)
                .font(AppTypography.subheadline)
                .foregroundStyle(Color(hex: "#F2F2F7"))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func begin() {
        Analytics.track("welcome_continued")
        welcomeSeen = true
    }
}
