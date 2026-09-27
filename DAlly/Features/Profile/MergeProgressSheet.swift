import SwiftUI

/// Shown while a phone's history joins a profile, then once with the result.
struct MergeProgressSheet: View {
    @Environment(\.colorScheme) private var scheme
    @State private var longWait = false

    private var sync: SyncEngine { SyncEngine.shared }

    var body: some View {
        VStack(spacing: 18) {
            if let summary = sync.mergeSummary {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(AppColors.aqua)
                Text(AppCopy.mergeDone)
                    .font(AppTypography.screenTitle)
                    .foregroundStyle(AppColors.textPrimary(scheme))
                Text(summaryLine(summary))
                    .font(AppTypography.subheadline)
                    .foregroundStyle(AppColors.textSecondary(scheme))
                Button {
                    sync.mergeSummary = nil
                } label: {
                    Text("Done")
                        .font(AppTypography.button)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .foregroundStyle(Color(hex: "#1C1C1E"))
                        .background(AppColors.aqua, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            } else {
                ProgressView()
                    .controlSize(.large)
                    .tint(AppColors.aqua)
                Text(AppCopy.mergeWorking)
                    .font(AppTypography.screenTitle)
                    .foregroundStyle(AppColors.textPrimary(scheme))
                Text("Nothing on this phone is removed.")
                    .font(AppTypography.footnote)
                    .foregroundStyle(AppColors.textSecondary(scheme))
                if longWait {
                    Text("This finishes in the background once you are online.")
                        .font(AppTypography.footnote)
                        .foregroundStyle(AppColors.textTertiary(scheme))
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(sync.mergeSummary == nil && !longWait)
        .task {
            try? await Task.sleep(for: .seconds(8))
            longWait = true
        }
    }

    private func summaryLine(_ summary: MergeSummary) -> String {
        let habits = summary.habits == 1 ? "1 habit" : "\(summary.habits) habits"
        let days = summary.days == 1 ? "1 day" : "\(summary.days) days"
        return "\(habits) · \(days)"
    }
}
