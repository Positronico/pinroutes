import Foundation
import SwiftUI

enum RouteStatus: Equatable {
    case unknown
    case active
    case missing
    case error(String)
}

@MainActor
final class AppState: ObservableObject {
    @Published var rules: [RouteRule] = []
    @Published var routeStatuses: [UUID: RouteStatus] = [:]
    @Published var settings: AppSettings = AppSettings()
    @Published var isApplying: Bool = false
    @Published var lastApplied: Date?
    @Published var lastChecked: Date?
    @Published var helperInstalled: Bool = false
    var hasBootstrapped = false

    var enabledRules: [RouteRule] {
        rules.filter(\.enabled)
    }

    var allEnabled: Bool {
        !rules.isEmpty && rules.allSatisfy(\.enabled)
    }

    var allDisabled: Bool {
        rules.isEmpty || rules.allSatisfy { !$0.enabled }
    }

    var hasMissingRoutes: Bool {
        enabledRules.contains { rule in
            let status = routeStatuses[rule.id] ?? .unknown
            return status == .missing || {
                if case .error = status { return true }
                return false
            }()
        }
    }

    var overallStatus: String {
        if isApplying { return "Applying routes..." }
        if rules.isEmpty { return "No routes configured" }
        let activeCount = routeStatuses.values.filter { $0 == .active }.count
        let enabledCount = enabledRules.count
        if enabledCount == 0 { return "No routes enabled" }
        if activeCount == enabledCount { return "All routes active (\(activeCount))" }
        return "\(activeCount)/\(enabledCount) routes active"
    }

    func statusFor(_ rule: RouteRule) -> RouteStatus {
        routeStatuses[rule.id] ?? .unknown
    }
}
