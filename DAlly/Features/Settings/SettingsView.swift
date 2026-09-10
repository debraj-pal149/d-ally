import SwiftUI
import SwiftData
import UIKit

struct SettingsView: View {
    @AppStorage(AppStorageKey.appearanceMode) private var appearanceMode = AppDefaults.appearanceMode
    @AppStorage(AppStorageKey.notificationsMasterEnabled) private var masterEnabled = AppDefaults.notificationsMasterEnabled
    @AppStorage(AppStorageKey.defaultOverdueMode) private var defaultOverdue = AppDefaults.defaultOverdueMode
    @AppStorage(AppStorageKey.hasCompletedOnboarding) private var hasCompletedOnboarding = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var scheme
    @State private var authState: NotificationAuthState = .notDetermined

    var body: some View {
        NavigationStack {
            ZStack {
                AppCanvas()
                List {
                    Section {
                        BrandMark()
                            .padding(.vertical, 8)
                    }
                    .listRowBackground(settingsRowBackground)

                    Section("Look") {
                        Picker("Theme", selection: $appearanceMode) {
                            ForEach(AppearanceMode.allCases) { mode in
                                Text(mode.displayName).tag(mode.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .listRowBackground(settingsRowBackground)

                    Section("Alerts") {
                        Toggle("Alerts", isOn: $masterEnabled)
                        Text(AppCopy.settingsAlertsBlurb)
                            .font(AppTypography.footnote)
                            .foregroundStyle(AppColors.textSecondary(scheme))
                        HStack {
                            Text("Status")
                            Spacer()
                            Text(authState.displayName)
                                .foregroundStyle(authState == .authorized ? AppColors.aqua : AppColors.textSecondary(scheme))
                        }
                        if authState == .denied {
                            Button("Open iOS Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .foregroundStyle(AppColors.aquaInk(scheme))
                        } else if authState == .notDetermined {
                            Button("Enable alerts") {
                                Task {
                                    _ = await NotificationPermissionService.shared.request()
                                    authState = await NotificationPermissionService.shared.currentState()
                                    NotificationSchedulingService.shared.rescheduleFromStore(context: modelContext)
                                }
                            }
                            .foregroundStyle(AppColors.aquaInk(scheme))
                        }
                    }
                    .listRowBackground(settingsRowBackground)

                    Section("Quiet hours") {
                        QuietHoursSettingsView()
                    }
                    .listRowBackground(settingsRowBackground)

                    Section("Defaults") {
                        Picker("If still open", selection: $defaultOverdue) {
                            ForEach(OverdueReminderMode.allCases) { mode in
                                Text(mode.displayName).tag(mode.rawValue)
                            }
                        }
                    }
                    .listRowBackground(settingsRowBackground)

                    Section("About") {
                        LabeledContent("App", value: AppCopy.brand)
                        LabeledContent("Version", value: "1.0.0")
                    }
                    .listRowBackground(settingsRowBackground)

                    Section("Data") {
                        Button("Show welcome again") {
                            hasCompletedOnboarding = false
                        }
                    }
                    .listRowBackground(settingsRowBackground)
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Settings")
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .task {
                authState = await NotificationPermissionService.shared.currentState()
            }
            .onChange(of: masterEnabled) { _, _ in
                NotificationSchedulingService.shared.rescheduleFromStore(context: modelContext)
            }
        }
    }

    private var settingsRowBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(AppColors.coolGlass(scheme))
    }
}
