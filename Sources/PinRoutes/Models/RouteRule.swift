import Foundation

struct RouteRule: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var network: String   // e.g. "10.255.255.0/24"
    var gateway: String   // e.g. "10.255.10.1"
    var enabled: Bool

    init(id: UUID = UUID(), name: String, network: String, gateway: String, enabled: Bool = true) {
        self.id = id
        self.name = name
        self.network = network
        self.gateway = gateway
        self.enabled = enabled
    }
}
