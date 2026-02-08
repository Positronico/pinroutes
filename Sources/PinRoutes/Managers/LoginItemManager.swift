import Foundation
import ServiceManagement

@MainActor
final class LoginItemManager: ObservableObject {
    @Published var isEnabled: Bool = false

    private static let defaultsKey = "launchAtLoginEnabled"

    init() {
        isEnabled = UserDefaults.standard.bool(forKey: Self.defaultsKey)
        if isEnabled {
            try? SMAppService.mainApp.register()
        }
    }

    func toggle() {
        if isEnabled {
            try? SMAppService.mainApp.unregister()
            UserDefaults.standard.set(false, forKey: Self.defaultsKey)
            isEnabled = false
        } else {
            do {
                try? SMAppService.mainApp.unregister()
                try SMAppService.mainApp.register()
                UserDefaults.standard.set(true, forKey: Self.defaultsKey)
                isEnabled = true
            } catch {
                log.error("[LoginItem] toggle failed: \(error.localizedDescription)")
            }
        }
    }
}
