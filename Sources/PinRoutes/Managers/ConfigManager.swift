import Foundation

enum ConfigManager {
    private static var configDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/PinRoutes")
    }

    private static var routesFile: URL {
        configDirectory.appendingPathComponent("routes.json")
    }

    private static var settingsFile: URL {
        configDirectory.appendingPathComponent("settings.json")
    }

    // MARK: - Routes

    static func load() -> [RouteRule] {
        let url = routesFile
        log.info("[Config] loading routes from \(url.path)")
        guard FileManager.default.fileExists(atPath: url.path) else {
            log.info("[Config] no routes file found, returning empty")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            let rules = try JSONDecoder().decode([RouteRule].self, from: data)
            log.info("[Config] loaded \(rules.count) rules")
            for rule in rules {
                log.info("[Config]   rule: '\(rule.name)' network=\(rule.network) gateway=\(rule.gateway) enabled=\(rule.enabled)")
            }
            return rules
        } catch {
            log.error("[Config] failed to load routes: \(error)")
            return []
        }
    }

    static func save(_ rules: [RouteRule]) {
        log.info("[Config] saving \(rules.count) rules")
        do {
            try FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(rules)
            try data.write(to: routesFile, options: .atomic)
            log.info("[Config] saved routes to \(routesFile.path)")
        } catch {
            log.error("[Config] failed to save routes: \(error)")
        }
    }

    // MARK: - Settings

    static func loadSettings() -> AppSettings {
        let url = settingsFile
        log.info("[Config] loading settings from \(url.path)")
        guard FileManager.default.fileExists(atPath: url.path) else {
            log.info("[Config] no settings file found, using defaults")
            return AppSettings()
        }
        do {
            let data = try Data(contentsOf: url)
            let settings = try JSONDecoder().decode(AppSettings.self, from: data)
            log.info("[Config] loaded settings: monitoring=\(settings.monitoringEnabled) interval=\(settings.checkIntervalSeconds)s autoReapply=\(settings.autoReapply)")
            return settings
        } catch {
            log.error("[Config] failed to load settings: \(error)")
            return AppSettings()
        }
    }

    static func saveSettings(_ settings: AppSettings) {
        log.info("[Config] saving settings: monitoring=\(settings.monitoringEnabled) interval=\(settings.checkIntervalSeconds)s autoReapply=\(settings.autoReapply)")
        do {
            try FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(settings)
            try data.write(to: settingsFile, options: .atomic)
            log.info("[Config] saved settings to \(settingsFile.path)")
        } catch {
            log.error("[Config] failed to save settings: \(error)")
        }
    }
}
