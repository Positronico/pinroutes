import Foundation
import os

struct AppLogger {
    private let logger = Logger(subsystem: "com.pinroutes.app", category: "general")
    private let fileHandle: FileHandle?
    private let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        return f
    }()

    init() {
        let logPath = "/tmp/pinroutes.log"
        if !FileManager.default.fileExists(atPath: logPath) {
            FileManager.default.createFile(atPath: logPath, contents: nil)
        }
        fileHandle = FileHandle(forWritingAtPath: logPath)
        fileHandle?.seekToEndOfFile()
    }

    func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
        write("INFO", message)
    }

    func warning(_ message: String) {
        logger.warning("\(message, privacy: .public)")
        write("WARN", message)
    }

    func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
        write("ERROR", message)
    }

    private func write(_ level: String, _ message: String) {
        let ts = formatter.string(from: Date())
        let line = "[\(ts)] \(level): \(message)\n"
        fileHandle?.seekToEndOfFile()
        fileHandle?.write(Data(line.utf8))
    }
}

let log = AppLogger()
