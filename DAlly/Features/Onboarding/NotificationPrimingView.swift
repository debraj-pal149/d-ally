import SwiftUI

struct NotificationPrimingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppStorageKey.hasRequestedNotificationPermission) private var hasRequested = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(AppCopy.primingTitle)
                    .font(AppTypography.screenTitle)
                Text(AppCopy.primingBody)
                    .font(AppTypography.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Button {
                    Task {
                        _ = await NotificationPermissionService.shared.request()
                        hasRequested = true
                        NotificationSchedulingService.shared.rescheduleFromStore(context: modelContext)
                        dismiss()
                    }
                } label: {
                    Text(AppCopy.enableAlerts)
                        .font(AppTypography.button)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.aqua)
                .padding(.top, 8)

                Button(AppCopy.notNow) { dismiss() }
                    .frame(maxWidth: .infinity)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.height(240), .medium])
        .presentationDragIndicator(.visible)
    }
}
