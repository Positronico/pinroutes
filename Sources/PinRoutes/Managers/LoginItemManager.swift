import Foundation
import ServiceManagement

@MainActor
final class LoginItemManager: ObservableObject {
    @Published var isEnabled: Bool = false

    init() {
        refresh()
    }

    func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func toggle() {
        do {
            if isEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            refresh()
        } catch {
            log.error("[LoginItem] toggle failed: \(error.localizedDescription)")
        }
    }

    /// Re-register the login item after an app update replaced the bundle.
    /// Call this on launch when settings indicate login was enabled.
    func reconcile(shouldBeEnabled: Bool) {
        let currentStatus = SMAppService.mainApp.status

        if shouldBeEnabled && currentStatus != .enabled {
            do {
                try SMAppService.mainApp.register()
                log.info("[LoginItem] re-registered after update")
            } catch {
                log.error("[LoginItem] re-register failed: \(error.localizedDescription)")
            }
        } else if !shouldBeEnabled && currentStatus == .enabled {
            do {
                try SMAppService.mainApp.unregister()
                log.info("[LoginItem] unregistered stale entry")
            } catch {
                log.error("[LoginItem] unregister failed: \(error.localizedDescription)")
            }
        }

        refresh()
    }

    /// Unregister before the app terminates for an update.
    func unregisterForUpdate() {
        guard SMAppService.mainApp.status == .enabled else { return }
        do {
            try SMAppService.mainApp.unregister()
            log.info("[LoginItem] unregistered before update")
        } catch {
            log.error("[LoginItem] pre-update unregister failed: \(error.localizedDescription)")
        }
    }
}
