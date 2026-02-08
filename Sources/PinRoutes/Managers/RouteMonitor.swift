import AppKit
import Foundation
import UserNotifications

private class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

@MainActor
final class RouteMonitor: ObservableObject {
    private var pollingTask: Task<Void, Never>?
    @Published var isRunning: Bool = false
    private static let notificationDelegate = NotificationDelegate()

    var onMissingRoutes: (([RouteRule]) -> Void)?

    func start(state: AppState) {
        stop()

        let interval = state.settings.checkIntervalSeconds
        log.info("[Monitor] starting periodic check every \(interval)s")
        isRunning = true

        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)
                guard !Task.isCancelled else { break }

                log.info("[Monitor] periodic check running")
                await RouteManager.verifyAll(rules: state.rules, state: state)
                state.lastChecked = Date()

                let missing = state.enabledRules.filter { rule in
                    let status = state.statusFor(rule)
                    return status == .missing || {
                        if case .error = status { return true }
                        return false
                    }()
                }

                if missing.isEmpty {
                    log.info("[Monitor] all routes active")
                } else {
                    let names = missing.map(\.name).joined(separator: ", ")
                    log.warning("[Monitor] missing routes: \(names)")

                    if state.settings.autoReapply {
                        log.info("[Monitor] auto-reapply enabled, applying routes")
                        await RouteManager.applyRoutes(state.rules, state: state)
                    } else {
                        log.info("[Monitor] notifying user about missing routes")
                        self?.sendNotification(missingNames: names)
                        self?.onMissingRoutes?(missing)
                    }
                }
            }

            await MainActor.run { [weak self] in
                self?.isRunning = false
            }
            log.info("[Monitor] polling stopped")
        }
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
        isRunning = false
        log.info("[Monitor] stopped")
    }

    private func sendNotification(missingNames: String) {
        let content = UNMutableNotificationContent()
        content.title = "PinRoutes"
        content.body = "Missing routes: \(missingNames)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "missing-routes-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                log.error("[Monitor] failed to send notification: \(error.localizedDescription)")
            }
        }
    }

    static func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.delegate = notificationDelegate
        NSApp.activate(ignoringOtherApps: true)
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                log.error("[Monitor] notification permission error: \(error.localizedDescription)")
            }
            log.info("[Monitor] notification permission granted: \(granted)")
        }
    }
}
