import Foundation

struct AppSettings: Codable, Equatable {
    var monitoringEnabled: Bool
    var checkIntervalSeconds: Int
    var autoReapply: Bool

    init(monitoringEnabled: Bool = true, checkIntervalSeconds: Int = 60, autoReapply: Bool = false) {
        self.monitoringEnabled = monitoringEnabled
        self.checkIntervalSeconds = checkIntervalSeconds
        self.autoReapply = autoReapply
    }
}
