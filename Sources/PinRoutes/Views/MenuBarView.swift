import SwiftUI

private struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct MenuBarView: View {
    @ObservedObject var state: AppState
    @ObservedObject var monitor: RouteMonitor
    @ObservedObject var loginItemManager: LoginItemManager
    @ObservedObject var updater: UpdateManager
    let popover: NSPopover

    enum Tab { case routes, settings }
    @State private var selectedTab: Tab = .routes
    @State private var isEditingRoute = false
    @State private var editingRule: RouteRule?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 6) {
                HStack {
                    Text("PinRoutes")
                        .font(.headline)
                    Spacer()
                    if state.isApplying {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                Picker("", selection: $selectedTab) {
                    Text("Routes").tag(Tab.routes)
                    Text("Settings").tag(Tab.settings)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)

            Divider()

            // Update banner
            if updater.updateAvailable {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(.blue)
                        .font(.caption)
                    Text("v\(updater.latestVersion) available")
                        .font(.caption)
                    Spacer()
                    if updater.isDownloading {
                        ProgressView(value: updater.downloadProgress)
                            .frame(width: 60)
                            .controlSize(.small)
                    } else {
                        Button("Update") {
                            Task { await updater.downloadAndInstall() }
                        }
                        .controlSize(.small)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.08))

                if let error = updater.errorMessage {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 4)
                }

                Divider()
            }

            // Tab content
            switch selectedTab {
            case .routes:
                if isEditingRoute {
                    RouteEditorView(
                        editingRule: editingRule,
                        onCancel: { isEditingRoute = false },
                        onSave: { rule in saveInlineRoute(rule) }
                    )
                } else {
                    RoutesTabView(
                        state: state,
                        onToggle: { rule in toggleRoute(rule) },
                        onEdit: { rule in
                            editingRule = rule
                            isEditingRoute = true
                        },
                        onDelete: { rule in deleteRoute(rule) },
                        onAdd: {
                            editingRule = nil
                            isEditingRoute = true
                        },
                        onEnableAll: { enableAll() },
                        onDisableAll: { disableAll() },
                        onApplyAll: {
                            Task { await RouteManager.applyRoutes(state.rules, state: state) }
                        },
                        onVerify: {
                            Task { await RouteManager.verifyAll(rules: state.rules, state: state) }
                        },
                        onReApply: {
                            Task { await RouteManager.applyRoutes(state.rules, state: state) }
                        }
                    )
                }

            case .settings:
                SettingsTabView(
                    loginItemManager: loginItemManager,
                    state: state,
                    monitor: monitor,
                    updater: updater,
                    onSettingsChanged: { restartMonitorIfNeeded() },
                    onInstallHelper: { installHelper() },
                    onUninstallHelper: { uninstallHelper() }
                )
            }

            Divider()

            // Footer
            HStack {
                Text(state.overallStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("v\(updater.currentVersion)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 320)
        .fixedSize(horizontal: false, vertical: true)
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: ViewHeightKey.self, value: geo.size.height)
            }
        )
        .onPreferenceChange(ViewHeightKey.self) { height in
            let maxH = (NSScreen.main?.visibleFrame.height ?? 800) * 0.8
            popover.contentSize = NSSize(width: 320, height: min(height, maxH))
        }
        .task {
            bootstrap()
        }
    }

    // MARK: - Bootstrap & Monitor

    private func bootstrap() {
        guard !state.hasBootstrapped else {
            log.info("[Bootstrap] already bootstrapped, skipping")
            return
        }
        state.hasBootstrapped = true
        log.info("[Bootstrap] starting bootstrap")

        state.rules = ConfigManager.load()
        state.settings = ConfigManager.loadSettings()
        state.helperInstalled = ShellExecutor.isHelperInstalled
        log.info("[Bootstrap] loaded \(state.rules.count) rules (\(state.enabledRules.count) enabled), helper=\(state.helperInstalled)")

        RouteMonitor.requestNotificationPermission()

        Task {
            if !state.enabledRules.isEmpty {
                log.info("[Bootstrap] applying enabled routes")
                await RouteManager.applyRoutes(state.rules, state: state)
            }

            if state.settings.monitoringEnabled {
                log.info("[Bootstrap] starting route monitor (interval: \(state.settings.checkIntervalSeconds)s)")
                monitor.start(state: state)
            }

            await updater.checkForUpdate()
            log.info("[Bootstrap] complete")
        }
    }

    private func restartMonitorIfNeeded() {
        monitor.stop()
        if state.settings.monitoringEnabled {
            monitor.start(state: state)
        }
    }

    // MARK: - Helper Management

    private func installHelper() {
        Task {
            let result = await ShellExecutor.installHelper()
            if result.exitCode == 0 {
                state.helperInstalled = ShellExecutor.isHelperInstalled
                log.info("[Helper] installed successfully")
            } else {
                log.error("[Helper] install failed: \(result.error)")
            }
        }
    }

    private func uninstallHelper() {
        Task {
            let result = await ShellExecutor.uninstallHelper()
            if result.exitCode == 0 {
                state.helperInstalled = ShellExecutor.isHelperInstalled
                log.info("[Helper] uninstalled successfully")
            } else {
                log.error("[Helper] uninstall failed: \(result.error)")
            }
        }
    }

    // MARK: - Route Actions

    private func toggleRoute(_ rule: RouteRule) {
        guard let index = state.rules.firstIndex(where: { $0.id == rule.id }) else { return }
        state.rules[index].enabled.toggle()
        let updated = state.rules[index]
        ConfigManager.save(state.rules)
        Task {
            if updated.enabled {
                await RouteManager.applySingleRoute(updated, state: state)
            } else {
                await RouteManager.removeSingleRoute(updated, state: state)
            }
        }
    }

    private func deleteRoute(_ rule: RouteRule) {
        Task {
            if rule.enabled {
                await RouteManager.removeSingleRoute(rule, state: state)
            }
            state.rules.removeAll { $0.id == rule.id }
            state.routeStatuses.removeValue(forKey: rule.id)
            ConfigManager.save(state.rules)
        }
    }

    private func saveInlineRoute(_ rule: RouteRule) {
        if let index = state.rules.firstIndex(where: { $0.id == rule.id }) {
            state.rules[index] = rule
        } else {
            state.rules.append(rule)
        }
        ConfigManager.save(state.rules)
        Task { await RouteManager.applyRoutes(state.rules, state: state) }
        isEditingRoute = false
    }

    private func enableAll() {
        for index in state.rules.indices {
            state.rules[index].enabled = true
        }
        ConfigManager.save(state.rules)
        Task { await RouteManager.applyRoutes(state.rules, state: state) }
    }

    private func disableAll() {
        let enabledRules = state.enabledRules
        Task {
            if !enabledRules.isEmpty {
                await RouteManager.removeRoutes(enabledRules, state: state)
            }
            for index in state.rules.indices {
                state.rules[index].enabled = false
            }
            ConfigManager.save(state.rules)
        }
    }
}
