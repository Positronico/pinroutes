import SwiftUI

struct RouteEditorView: View {
    var editingRule: RouteRule?
    var onCancel: () -> Void
    var onSave: (RouteRule) -> Void

    @State private var name: String = ""
    @State private var network: String = ""
    @State private var gateway: String = ""
    @State private var enabled: Bool = true
    @State private var validationError: String?

    private var isEditing: Bool { editingRule != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(isEditing ? "Edit Route" : "Add Route")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                TextField("Name", text: $name, prompt: Text("e.g. Office Printer"))
                    .textFieldStyle(.roundedBorder)
                TextField("Network (CIDR)", text: $network, prompt: Text("e.g. 10.255.255.0/24"))
                    .textFieldStyle(.roundedBorder)
                TextField("Gateway", text: $gateway, prompt: Text("e.g. 10.255.10.1"))
                    .textFieldStyle(.roundedBorder)
                Toggle("Enabled", isOn: $enabled)
            }

            if let error = validationError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(isEditing ? "Save" : "Add") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.isEmpty || network.isEmpty || gateway.isEmpty)
            }
        }
        .padding(12)
        .onAppear {
            if let rule = editingRule {
                name = rule.name
                network = rule.network
                gateway = rule.gateway
                enabled = rule.enabled
            }
        }
    }

    private func save() {
        let trimmedNetwork = network.trimmingCharacters(in: .whitespaces)
        let trimmedGateway = gateway.trimmingCharacters(in: .whitespaces)

        guard NetworkValidation.isValidCIDR(trimmedNetwork) else {
            validationError = "Invalid CIDR notation. Use format: x.x.x.x/prefix"
            return
        }
        guard NetworkValidation.isValidGateway(trimmedGateway) else {
            validationError = "Invalid gateway IP address."
            return
        }

        var rule = editingRule ?? RouteRule(
            name: "",
            network: "",
            gateway: "",
            enabled: true
        )
        rule.name = name.trimmingCharacters(in: .whitespaces)
        rule.network = trimmedNetwork
        rule.gateway = trimmedGateway
        rule.enabled = enabled

        onSave(rule)
    }
}
