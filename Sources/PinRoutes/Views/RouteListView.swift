import SwiftUI

struct RoutesTabView: View {
    @ObservedObject var state: AppState
    var onToggle: (RouteRule) -> Void
    var onEdit: (RouteRule) -> Void
    var onDelete: (RouteRule) -> Void
    var onAdd: () -> Void
    var onEnableAll: () -> Void
    var onDisableAll: () -> Void
    var onApplyAll: () -> Void
    var onVerify: () -> Void
    var onReApply: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if state.hasMissingRoutes && !state.isApplying {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                    let missingCount = state.enabledRules.filter { rule in
                        let s = state.statusFor(rule)
                        return s == .missing || { if case .error = s { return true }; return false }()
                    }.count
                    Text("\(missingCount) route\(missingCount == 1 ? "" : "s") missing")
                        .font(.caption)
                    Spacer()
                    Button("Re-Apply") { onReApply() }
                        .controlSize(.small)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.orange.opacity(0.1))

                Divider()
            }

            if state.rules.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "network")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                    Text("No routes configured")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                VStack(spacing: 0) {
                    ForEach(state.rules) { rule in
                        RouteRowView(
                            rule: rule,
                            status: state.statusFor(rule),
                            onToggle: { onToggle(rule) },
                            onEdit: { onEdit(rule) },
                            onDelete: { onDelete(rule) }
                        )

                        if rule.id != state.rules.last?.id {
                            Divider()
                                .padding(.leading, 24)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }

            Button {
                onAdd()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                    Text("Add Route")
                }
                .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.blue)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            HStack(spacing: 8) {
                Button("All On") { onEnableAll() }
                    .controlSize(.small)
                    .disabled(state.isApplying || state.rules.isEmpty || state.allEnabled)
                Button("All Off") { onDisableAll() }
                    .controlSize(.small)
                    .disabled(state.isApplying || state.rules.isEmpty || state.allDisabled)

                Spacer()

                Button("Apply") { onApplyAll() }
                    .controlSize(.small)
                    .disabled(state.isApplying || state.enabledRules.isEmpty)

                Button {
                    onVerify()
                } label: {
                    Image(systemName: "checkmark.circle")
                }
                .controlSize(.small)
                .disabled(state.isApplying || state.enabledRules.isEmpty)
                .help("Verify all routes")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}

struct RouteRowView: View {
    let rule: RouteRule
    let status: RouteStatus
    var onToggle: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void

    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                statusIndicator

                Text(rule.name)
                    .font(.system(.body, weight: .medium))
                    .foregroundStyle(rule.enabled ? .primary : .secondary)

                Spacer()

                Button {
                    onEdit()
                } label: {
                    Image(systemName: "pencil")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Button {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Toggle("", isOn: Binding(
                    get: { rule.enabled },
                    set: { _ in onToggle() }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
            }

            Text("\(rule.network) \u{2192} \(rule.gateway)")
                .font(.caption)
                .foregroundStyle(rule.enabled ? .secondary : .tertiary)
                .padding(.leading, 14)
        }
        .padding(.vertical, 4)
        .confirmationDialog(
            "Delete \"\(rule.name)\"?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { onDelete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the route and cannot be undone.")
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        let (color, tooltip): (Color, String) = {
            switch status {
            case .active: return (.green, "Active")
            case .missing: return (.orange, "Missing")
            case .error(let msg): return (.red, "Error: \(msg)")
            case .unknown: return (.gray, "Unknown")
            }
        }()

        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .help(tooltip)
    }
}
