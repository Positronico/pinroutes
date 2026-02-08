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
    private let updater = UpdateManager()
    private var cancellable: AnyCancellable?
    private var onboardingWindow: NSWindow?

    private static let alertIcon = "exclamationmark.triangle.fill"

    private static func makePinIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let s = rect.height

            let path = NSBezierPath()
            path.windingRule = .evenOdd

            // Outer pin shape (same bezier curves as app icon)
            path.move(to: NSPoint(x: s * 0.5, y: s * 0.08))
            path.curve(to: NSPoint(x: s * 0.78, y: s * 0.55),
                        controlPoint1: NSPoint(x: s * 0.68, y: s * 0.24),
                        controlPoint2: NSPoint(x: s * 0.78, y: s * 0.40))
            path.curve(to: NSPoint(x: s * 0.5, y: s * 0.92),
                        controlPoint1: NSPoint(x: s * 0.78, y: s * 0.72),
                        controlPoint2: NSPoint(x: s * 0.65, y: s * 0.92))
            path.curve(to: NSPoint(x: s * 0.22, y: s * 0.55),
                        controlPoint1: NSPoint(x: s * 0.35, y: s * 0.92),
                        controlPoint2: NSPoint(x: s * 0.22, y: s * 0.72))
            path.curve(to: NSPoint(x: s * 0.5, y: s * 0.08),
                        controlPoint1: NSPoint(x: s * 0.22, y: s * 0.40),
                        controlPoint2: NSPoint(x: s * 0.32, y: s * 0.24))
            path.close()

            // Inner circle cutout (even-odd creates the hole)
            let r = s * 0.14
            let cy = s * 0.62
            path.appendOval(in: NSRect(x: s * 0.5 - r, y: cy - r, width: r * 2, height: r * 2))

            NSColor.black.setFill()
            path.fill()
            return true
        }
        image.isTemplate = true
        return image
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.windows.forEach { $0.close() }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = Self.makePinIcon()
            button.action = #selector(togglePopover)
            button.target = self
        }

        let hostingController = NSHostingController(
            rootView: MenuBarView(state: state, monitor: monitor, loginItemManager: loginItemManager, updater: updater)
        )
        popover.contentViewController = hostingController
        popover.behavior = .transient

        cancellable = state.$routeStatuses
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateIcon() }

        showOnboardingIfNeeded()
    }

    private func showOnboardingIfNeeded() {
        let key = "hasShownOnboarding"
        guard !ShellExecutor.isHelperInstalled,
              !UserDefaults.standard.bool(forKey: key) else { return }

        UserDefaults.standard.set(true, forKey: key)

        let view = OnboardingView(
            onInstall: { [weak self] in
                self?.dismissOnboarding()
                Task {
                    let result = await ShellExecutor.installHelper()
                    if result.exitCode == 0 {
                        self?.state.helperInstalled = ShellExecutor.isHelperInstalled
                    }
                }
            },
            onSkip: { [weak self] in
                self?.dismissOnboarding()
            }
        )

        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to PinRoutes"
        window.contentView = NSHostingView(rootView: view)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        onboardingWindow = window
    }

    private func dismissOnboarding() {
        onboardingWindow?.orderOut(nil)
        onboardingWindow = nil
        NSApp.setActivationPolicy(.accessory)
    }

    private func updateIcon() {
        if state.hasMissingRoutes {
            statusItem.button?.image = NSImage(systemSymbolName: Self.alertIcon, accessibilityDescription: "PinRoutes")
        } else {
            statusItem.button?.image = Self.makePinIcon()
        }
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
