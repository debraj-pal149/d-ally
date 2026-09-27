import SwiftUI

/// Second onboarding step. Sign in now, or keep everything on this phone.
struct ProfileSetupView: View {
    @AppStorage(AppStorageKey.hasCompletedOnboarding) private var hasCompletedOnboarding = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#1A1A1E"), Color(hex: "#121214"), Color(hex: "#0C0C0E")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    BrandWordmark(size: 22, weight: .bold, color: Color(hex: "#F2F2F7"))

                    ZStack {
                        Circle()
                            .fill(AppColors.aqua.opacity(0.14))
                            .frame(width: 96, height: 96)
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 52, weight: .light))
                            .foregroundStyle(AppColors.aqua)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 48)

                    Text(AppCopy.profileSetupTitle)
                        .font(AppTypography.heroTitle)
                        .foregroundStyle(Color(hex: "#F2F2F7"))
                        .padding(.top, 28)

                    Text(AppCopy.profileSetupBody)
                        .font(AppTypography.subheadline)
                        .foregroundStyle(Color(hex: "#A1A1A6"))
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 28)
                .padding(.top, 24)

                VStack(spacing: 14) {
                    SignInButtons(onSignedIn: finish, onDark: true)

                    Button(AppCopy.profileContinueGuest, action: finish)
                        .font(AppTypography.callout)
                        .foregroundStyle(Color(hex: "#F2F2F7"))
                        .padding(.top, 6)
                        .accessibilityIdentifier("continue-guest")

                    Text(AppCopy.profileGuestFootnote)
                        .font(AppTypography.footnote)
                        .foregroundStyle(Color(hex: "#6C6C70"))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func finish() {
        hasCompletedOnboarding = true
    }
}
