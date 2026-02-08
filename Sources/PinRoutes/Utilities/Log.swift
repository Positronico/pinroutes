import Foundation
import os

struct AppLogger {
    private let logger = Logger(subsystem: "com.pinroutes.app", category: "general")

    func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    func warning(_ message: String) {
        logger.warning("\(message, privacy: .public)")
    }

    func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }
}

let log = AppLogger()
