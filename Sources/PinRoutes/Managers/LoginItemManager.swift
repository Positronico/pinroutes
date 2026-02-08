import Foundation
import ServiceManagement

@MainActor
final class LoginItemManager: ObservableObject {
    @Published var isEnabled: Bool = false

    init() {
        refresh()
    }

    func refresh() {
        if #available(macOS 13.0, *) {
            isEnabled = SMAppService.mainApp.status == .enabled
        }
    }

    func toggle() {
        if #available(macOS 13.0, *) {
            do {
                if isEnabled {
                    try SMAppService.mainApp.unregister()
                } else {
                    try SMAppService.mainApp.register()
                }
                refresh()
            } catch {
                print("Failed to toggle login item: \(error)")
            }
        }
    }
}
