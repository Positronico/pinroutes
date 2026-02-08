import Combine
import SwiftUI

@main
struct PinRoutesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let state = AppState()
    private let monitor = RouteMonitor()
    private let loginItemManager = LoginItemManager()
    private var cancellable: AnyCancellable?

    private static let normalIcon = "point.topright.arrow.triangle.backward.to.point.bottomleft.scurvepath.fill"
    private static let alertIcon = "exclamationmark.triangle.fill"

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: Self.normalIcon, accessibilityDescription: "PinRoutes")
            button.action = #selector(togglePopover)
            button.target = self
        }

        let hostingController = NSHostingController(
            rootView: MenuBarView(state: state, monitor: monitor, loginItemManager: loginItemManager)
        )
        popover.contentViewController = hostingController
        popover.behavior = .transient

        cancellable = state.$routeStatuses
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateIcon() }
    }

    private func updateIcon() {
        let name = state.hasMissingRoutes ? Self.alertIcon : Self.normalIcon
        statusItem.button?.image = NSImage(systemSymbolName: name, accessibilityDescription: "PinRoutes")
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
