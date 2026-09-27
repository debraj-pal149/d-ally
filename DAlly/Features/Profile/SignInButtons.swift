import SwiftUI

/// Google and Apple sign-in, stacked. Reports success so the caller can move on.
struct SignInButtons: View {
    var onSignedIn: () -> Void
    var onDark: Bool = false

    @State private var errorText: String?
    @State private var busy = false
    @Environment(\.colorScheme) private var scheme

    private var auth: AuthService { AuthService.shared }

    var body: some View {
        VStack(spacing: 10) {
            Button {
                run { try await auth.signInWithGoogle() }
            } label: {
                HStack(spacing: 10) {
                    Image("GoogleLogo")
                        .resizable()
                        .frame(width: 18, height: 18)
                        .accessibilityHidden(true)
                    Text(AppCopy.profileContinueGoogle)
                        .font(AppTypography.button)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .foregroundStyle(Color(hex: "#1C1C1E"))
                .background(Color.white, in: Capsule())
                .overlay {
                    Capsule().stroke(Color.black.opacity(0.12), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("signin-google")

            Button {
                run { try await auth.signInWithApple() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 18, weight: .medium))
                    Text("Continue with Apple")
                        .font(AppTypography.button)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .foregroundStyle(appleForeground)
                .background(appleBackground, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("signin-apple")

            if let errorText {
                Text(errorText)
                    .font(AppTypography.footnote)
                    .foregroundStyle(AppColors.danger(scheme))
                    .multilineTextAlignment(.center)
            }
        }
        .disabled(busy)
        .opacity(busy ? 0.7 : 1)
    }

    private var appleBackground: Color {
        (onDark || scheme == .dark) ? Color.white : Color.black
    }

    private var appleForeground: Color {
        (onDark || scheme == .dark) ? Color.black : Color.white
    }

    private func run(_ work: @escaping () async throws -> Void) {
        errorText = nil
        busy = true
        Task {
            defer { busy = false }
            do {
                try await work()
                onSignedIn()
            } catch let error as AuthError {
                if error != .cancelled {
                    errorText = error.errorDescription
                }
            } catch {
                errorText = error.localizedDescription
            }
        }
    }
}

extension AuthError: Equatable {}

