import SwiftUI

struct OnboardingView: View {
    var onInstall: () -> Void
    var onSkip: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.open.rotation")
                .font(.system(size: 44))
                .foregroundStyle(.blue)
                .padding(.top, 4)

            Text("Passwordless Route Management")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 12) {
                Text("PinRoutes needs administrator privileges to manage network routes. By default, macOS asks for your password each time a route is added or removed.")
                    .fixedSize(horizontal: false, vertical: true)

                Text("Install a lightweight helper to skip the password prompt. It only runs /sbin/route commands — nothing else. You'll enter your password once during setup.")
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.body)
            .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("Later") { onSkip() }
                    .keyboardShortcut(.cancelAction)

                Button("Install Helper") { onInstall() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
            .padding(.top, 4)
        }
        .padding(32)
        .frame(width: 420)
    }
}
