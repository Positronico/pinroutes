import Foundation

@MainActor
enum RouteManager {
    static func verifyRoute(_ rule: RouteRule) async -> RouteStatus {
        guard let network = NetworkValidation.networkAddress(from: rule.network) else {
            log.error("[RouteManager] verifyRoute: invalid network in rule '\(rule.name)' network='\(rule.network)'")
            return .error("Invalid network")
        }

        log.info("[RouteManager] verifyRoute '\(rule.name)': route -n get \(network)")
        let result = await ShellExecutor.run("/sbin/route -n get \(network)")
        if result.exitCode != 0 {
            log.warning("[RouteManager] verifyRoute '\(rule.name)': route get failed exit=\(result.exitCode) err=\(result.error)")
            return .missing
        }

        let lines = result.output.lowercased()
            .split(separator: "\n")
            .reduce(into: [String: String]()) { dict, line in
                let parts = line.split(separator: ":", maxSplits: 1)
                if parts.count == 2 {
                    dict[parts[0].trimmingCharacters(in: .whitespaces)] = parts[1].trimmingCharacters(in: .whitespaces)
                }
            }

        let destMatch = lines["destination"] == network.lowercased()
        let gwMatch = lines["gateway"] == rule.gateway.lowercased()

        log.info("[RouteManager] verifyRoute '\(rule.name)': destination='\(lines["destination"] ?? "nil")' expected='\(network)' match=\(destMatch)")
        log.info("[RouteManager] verifyRoute '\(rule.name)': gateway='\(lines["gateway"] ?? "nil")' expected='\(rule.gateway)' match=\(gwMatch)")

        if destMatch && gwMatch {
            log.info("[RouteManager] verifyRoute '\(rule.name)': ACTIVE")
            return .active
        }
        log.info("[RouteManager] verifyRoute '\(rule.name)': MISSING (destination=\(destMatch) gateway=\(gwMatch))")
        return .missing
    }

    static func verifyAll(rules: [RouteRule], state: AppState) async {
        log.info("[RouteManager] verifyAll: \(rules.filter(\.enabled).count) enabled rules")
        for rule in rules where rule.enabled {
            let status = await verifyRoute(rule)
            state.routeStatuses[rule.id] = status
        }
    }

    static func applyRoutes(_ rules: [RouteRule], state: AppState) async {
        let enabledRules = rules.filter(\.enabled)
        log.info("[RouteManager] applyRoutes: \(enabledRules.count) enabled rules")
        guard !enabledRules.isEmpty else {
            log.info("[RouteManager] applyRoutes: no enabled rules, skipping")
            return
        }

        state.isApplying = true
        defer {
            state.isApplying = false
            state.lastApplied = Date()
            log.info("[RouteManager] applyRoutes: done")
        }

        var missingRules: [RouteRule] = []
        for rule in enabledRules {
            let status = await verifyRoute(rule)
            if status != .active {
                missingRules.append(rule)
            } else {
                state.routeStatuses[rule.id] = .active
            }
        }

        log.info("[RouteManager] applyRoutes: \(missingRules.count) routes missing, need to apply")
        guard !missingRules.isEmpty else {
            log.info("[RouteManager] applyRoutes: all routes already active")
            return
        }

        let commands = missingRules.flatMap { rule in [
            (action: "delete", network: rule.network, gateway: rule.gateway),
            (action: "add", network: rule.network, gateway: rule.gateway),
        ]}

        log.info("[RouteManager] applyRoutes: running \(commands.count) route commands")
        let result = await executeRouteCommands(commands)
        log.info("[RouteManager] applyRoutes: result exit=\(result.exitCode) out=\(result.output.prefix(300)) err=\(result.error.prefix(300))")

        for rule in missingRules {
            let status = await verifyRoute(rule)
            state.routeStatuses[rule.id] = status
            if case .missing = status, result.exitCode != 0 {
                let errMsg = result.error.isEmpty ? "Failed to apply" : result.error
                log.error("[RouteManager] applyRoutes: route '\(rule.name)' still missing after apply, error: \(errMsg)")
                state.routeStatuses[rule.id] = .error(errMsg)
            }
        }
    }

    static func removeRoutes(_ rules: [RouteRule], state: AppState) async {
        let enabledRules = rules.filter(\.enabled)
        guard !enabledRules.isEmpty else { return }

        log.info("[RouteManager] removeRoutes: removing \(enabledRules.count) routes")
        state.isApplying = true
        defer { state.isApplying = false }

        let commands = enabledRules.map { rule in
            (action: "delete", network: rule.network, gateway: rule.gateway)
        }

        let result = await executeRouteCommands(commands)
        log.info("[RouteManager] removeRoutes: result exit=\(result.exitCode)")

        for rule in enabledRules {
            state.routeStatuses[rule.id] = .missing
        }
    }

    static func applySingleRoute(_ rule: RouteRule, state: AppState) async {
        log.info("[RouteManager] applySingleRoute '\(rule.name)': \(rule.network) via \(rule.gateway)")
        state.isApplying = true
        defer {
            state.isApplying = false
            state.lastApplied = Date()
        }

        let commands = [
            (action: "delete", network: rule.network, gateway: rule.gateway),
            (action: "add", network: rule.network, gateway: rule.gateway),
        ]

        let result = await executeRouteCommands(commands)
        log.info("[RouteManager] applySingleRoute: result exit=\(result.exitCode) out=\(result.output.prefix(300)) err=\(result.error.prefix(300))")

        let status = await verifyRoute(rule)
        state.routeStatuses[rule.id] = status
        if case .missing = status, result.exitCode != 0 {
            let errMsg = result.error.isEmpty ? "Failed to apply" : result.error
            log.error("[RouteManager] applySingleRoute '\(rule.name)': still missing, error: \(errMsg)")
            state.routeStatuses[rule.id] = .error(errMsg)
        }
    }

    static func removeSingleRoute(_ rule: RouteRule, state: AppState) async {
        log.info("[RouteManager] removeSingleRoute '\(rule.name)': \(rule.network)")
        state.isApplying = true
        defer { state.isApplying = false }

        let commands = [(action: "delete", network: rule.network, gateway: rule.gateway)]
        let result = await executeRouteCommands(commands)
        log.info("[RouteManager] removeSingleRoute: result exit=\(result.exitCode)")
        state.routeStatuses[rule.id] = .missing
    }

    private static func executeRouteCommands(_ commands: [(action: String, network: String, gateway: String)]) async -> ShellExecutor.Result {
        if ShellExecutor.isHelperInstalled {
            log.info("[RouteManager] using helper for \(commands.count) commands")
            var lastResult = ShellExecutor.Result(exitCode: 0, output: "", error: "")
            for cmd in commands {
                lastResult = await ShellExecutor.runViaHelper([cmd.action, cmd.network, cmd.gateway])
                if lastResult.exitCode != 0 && cmd.action != "delete" {
                    return lastResult
                }
            }
            return lastResult
        } else {
            log.info("[RouteManager] using privileged shell for \(commands.count) commands")
            let shellCommands = commands.map { cmd in
                if cmd.action == "delete" {
                    return "/sbin/route -n \(cmd.action) \(cmd.network) \(cmd.gateway) 2>/dev/null"
                }
                return "/sbin/route -n \(cmd.action) \(cmd.network) \(cmd.gateway)"
            }
            return await ShellExecutor.runPrivileged(shellCommands)
        }
    }
}
