import SwiftUI

struct SettingsTabView: View {
    @ObservedObject var loginItemManager: LoginItemManager
    @ObservedObject var state: AppState
    @ObservedObject var monitor: RouteMonitor
    var onSettingsChanged: () -> Void
    var onInstallHelper: () -> Void
    var onUninstallHelper: () -> Void

    private let intervalOptions = [15, 30, 60, 120, 300, 600]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("GENERAL")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Toggle("Launch at Login", isOn: Binding(
                get: { loginItemManager.isEnabled },
                set: { _ in loginItemManager.toggle() }
            ))

            Divider()
                .padding(.vertical, 4)

            Text("ROUTE MONITORING")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Periodic Check", isOn: Binding(
                get: { state.settings.monitoringEnabled },
                set: { newValue in
                    state.settings.monitoringEnabled = newValue
                    saveSettings()
                }
            ))

            if state.settings.monitoringEnabled {
                Picker("Check every", selection: Binding(
                    get: { state.settings.checkIntervalSeconds },
                    set: { newValue in
                        state.settings.checkIntervalSeconds = newValue
                        saveSettings()
                    }
                )) {
                    ForEach(intervalOptions, id: \.self) { seconds in
                        Text(formatInterval(seconds)).tag(seconds)
                    }
                }

                Picker("When missing", selection: Binding(
                    get: { state.settings.autoReapply },
                    set: { newValue in
                        state.settings.autoReapply = newValue
                        saveSettings()
                    }
                )) {
                    Text("Notify only").tag(false)
                    Text("Re-apply automatically").tag(true)
                }

                HStack(spacing: 4) {
                    Circle()
                        .fill(monitor.isRunning ? .green : .gray)
                        .frame(width: 6, height: 6)
                    Text(monitor.isRunning ? "Monitor running" : "Monitor stopped")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)
            }

            if let lastChecked = state.lastChecked {
                Text("Last checked: \(lastChecked.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let lastApplied = state.lastApplied {
                Text("Last applied: \(lastApplied.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()
                .padding(.vertical, 4)

            Text("PRIVILEGED HELPER")
                .font(.caption)
                .foregroundStyle(.secondary)

            if state.helperInstalled {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                    Text("Helper installed")
                        .font(.caption)
                    Spacer()
                    Button("Uninstall") { onUninstallHelper() }
                        .controlSize(.small)
                }
            } else {
                HStack {
                    Button("Install Helper") { onInstallHelper() }
                        .controlSize(.small)
                    Text("Eliminates password prompts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private func saveSettings() {
        ConfigManager.saveSettings(state.settings)
        onSettingsChanged()
    }

    private func formatInterval(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        return "\(minutes) min"
    }
}
