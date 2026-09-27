import SwiftData
import SwiftUI

struct ProfileView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    @Query private var tasks: [DailyTask]
    @Query private var logs: [TaskDayLog]

    @State private var showSignOut = false
    @State private var showDelete = false
    @State private var alertText: String?
    @State private var exportURL: URL?

    private var auth: AuthService { AuthService.shared }
    private var sync: SyncEngine { SyncEngine.shared }

    var body: some View {
        NavigationStack {
            ZStack {
                AppCanvas()
                List {
                    Section {
                        header
                    }
                    .listRowBackground(rowBackground)

                    if auth.isSignedIn {
                        Section("Sync") {
                            syncRow
                        }
                        .listRowBackground(rowBackground)
                    }

                    Section("Your habits") {
                        LabeledContent("Habits", value: "\(activeHabits)")
                        LabeledContent("Since", value: sinceLabel)
                        LabeledContent("Days marked", value: "\(logs.count)")
                    }
                    .listRowBackground(rowBackground)

                    if !auth.isSignedIn {
                        Section {
                            SignInButtons(onSignedIn: {})
                                .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                            Text(signInFootnote)
                                .font(AppTypography.footnote)
                                .foregroundStyle(AppColors.textSecondary(scheme))
                        }
                        .listRowBackground(rowBackground)
                    }

                    Section {
                        exportRow
                    }
                    .listRowBackground(rowBackground)

                    if auth.isSignedIn {
                        Section {
                            Button(AppCopy.profileSignOut) { showSignOut = true }
                                .foregroundStyle(AppColors.textPrimary(scheme))
                            Button(AppCopy.profileDelete, role: .destructive) { showDelete = true }
                        }
                        .listRowBackground(rowBackground)
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Profile")
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .confirmationDialog(AppCopy.profileSignOutTitle, isPresented: $showSignOut, titleVisibility: .visible) {
                Button(AppCopy.profileSignOutKeep) { signOut(keep: true) }
                Button(AppCopy.profileSignOutRemove, role: .destructive) { signOut(keep: false) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(AppCopy.profileSignOutBody)
            }
            .alert(AppCopy.profileDeleteTitle, isPresented: $showDelete) {
                Button("Delete", role: .destructive, action: deleteAccount)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(AppCopy.profileDeleteBody)
            }
            .alert("Profile", isPresented: Binding(get: { alertText != nil }, set: { if !$0 { alertText = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertText ?? "")
            }
        }
    }

    // MARK: Sections

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 14) {
            avatar
            VStack(alignment: .leading, spacing: 3) {
                Text(auth.user?.title ?? AppCopy.profileLocalOnly)
                    .font(AppTypography.taskName)
                    .foregroundStyle(AppColors.textPrimary(scheme))
                    .lineLimit(1)
                Text(auth.user?.subtitle ?? AppCopy.profileLocalBody)
                    .font(AppTypography.footnote)
                    .foregroundStyle(AppColors.textSecondary(scheme))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var avatar: some View {
        if let url = auth.user?.photoURL {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                avatarPlaceholder
            }
            .frame(width: 52, height: 52)
            .clipShape(Circle())
        } else {
            avatarPlaceholder
        }
    }

    private var avatarPlaceholder: some View {
        ZStack {
            Circle()
                .fill(auth.isSignedIn ? AppColors.aqua.opacity(0.2) : AppColors.rowFill(scheme))
            Image(systemName: "person.fill")
                .font(.system(size: 22))
                .foregroundStyle(auth.isSignedIn ? AppColors.aquaInk(scheme) : AppColors.textTertiary(scheme))
        }
        .frame(width: 52, height: 52)
    }

    @ViewBuilder
    private var syncRow: some View {
        HStack(spacing: 10) {
            Image(systemName: syncSymbol)
                .foregroundStyle(syncTint)
            Text(syncText)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textPrimary(scheme))
            Spacer()
            if case .error = sync.state {
                Button("Retry") { sync.pushNow() }
                    .font(AppTypography.captionSemibold)
                    .foregroundStyle(AppColors.aquaInk(scheme))
            }
        }
    }

    private var exportRow: some View {
        Group {
            if let exportURL {
                ShareLink(item: exportURL) {
                    Label(AppCopy.profileExport, systemImage: "square.and.arrow.up")
                        .foregroundStyle(AppColors.textPrimary(scheme))
                }
            } else {
                Button {
                    exportURL = try? HistoryExport.makeFile(tasks: tasks, logs: logs)
                } label: {
                    Label(AppCopy.profileExport, systemImage: "square.and.arrow.up")
                        .foregroundStyle(AppColors.textPrimary(scheme))
                }
            }
        }
        .onChange(of: logs.count) { _, _ in exportURL = nil }
        .onChange(of: tasks.count) { _, _ in exportURL = nil }
    }

    // MARK: Derived

    private var activeHabits: Int {
        tasks.filter { !$0.isStopped }.count
    }

    private var sinceLabel: String {
        guard let first = tasks.map(\.startDate).min() else { return "—" }
        return first.formatted(.dateTime.month(.abbreviated).year())
    }

    private var signInFootnote: String {
        let habits = activeHabits == 1 ? "1 habit" : "\(activeHabits) habits"
        let days = logs.count == 1 ? "1 marked day" : "\(logs.count) marked days"
        if tasks.isEmpty { return "Your habits and history will follow you to every phone." }
        return "Your \(habits) and \(days) come with you."
    }

    private var syncText: String {
        switch sync.state {
        case .off: return "Not syncing"
        case .syncing: return "Syncing…"
        case .synced(let date): return "Synced \(date.formatted(.relative(presentation: .named)))"
        case .offline: return "Offline, changes saved here"
        case .error: return "Sync failed"
        }
    }

    private var syncSymbol: String {
        switch sync.state {
        case .off: return "icloud.slash"
        case .syncing: return "arrow.triangle.2.circlepath"
        case .synced: return "checkmark.icloud"
        case .offline: return "wifi.slash"
        case .error: return "exclamationmark.icloud"
        }
    }

    private var syncTint: Color {
        switch sync.state {
        case .synced: return AppColors.aquaInk(scheme)
        case .error: return AppColors.danger(scheme)
        case .offline: return AppColors.warning
        default: return AppColors.textSecondary(scheme)
        }
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(AppColors.coolGlass(scheme))
    }

    // MARK: Actions

    private func signOut(keep: Bool) {
        do {
            try auth.signOut(keepLocalData: keep)
        } catch {
            alertText = error.localizedDescription
        }
    }

    private func deleteAccount() {
        Task {
            do {
                try await auth.deleteAccount()
            } catch {
                alertText = (error as? AuthError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}
