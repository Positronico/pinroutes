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
                try? SMAppService.mainApp.unregister()
                try SMAppService.mainApp.register()
            }
            refresh()
        } catch {
            log.error("[LoginItem] toggle failed: \(error.localizedDescription)")
        }
    }
}
