import Foundation

enum ShellExecutor {
    struct Result {
        let exitCode: Int32
        let output: String
        let error: String
    }

    static let helperPath = "/usr/local/bin/pinroutes-helper"

    static var isHelperInstalled: Bool {
        FileManager.default.isExecutableFile(atPath: helperPath)
    }

    static func runViaHelper(_ args: [String]) async -> Result {
        log.info("[Shell] runViaHelper: \(helperPath) \(args.joined(separator: " "))")
        let result: Result = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let stdout = Pipe()
                let stderr = Pipe()

                process.executableURL = URL(fileURLWithPath: helperPath)
                process.arguments = args
                process.standardOutput = stdout
                process.standardError = stderr

                do {
                    try process.run()
                    process.waitUntilExit()

                    let outData = stdout.fileHandleForReading.readDataToEndOfFile()
                    let errData = stderr.fileHandleForReading.readDataToEndOfFile()

                    let result = Result(
                        exitCode: process.terminationStatus,
                        output: String(data: outData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                        error: String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    )
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(returning: Result(exitCode: -1, output: "", error: error.localizedDescription))
                }
            }
        }
        log.info("[Shell] runViaHelper exit=\(result.exitCode) stdout=\(result.output.prefix(500)) stderr=\(result.error.prefix(500))")
        return result
    }

    static func installHelper() async -> Result {
        guard let bundlePath = Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent("pinroutes-helper").path else {
            return Result(exitCode: -1, output: "", error: "Could not locate pinroutes-helper in app bundle")
        }

        let commands = [
            "cp \"\(bundlePath)\" \"\(helperPath)\"",
            "chown root:wheel \"\(helperPath)\"",
            "chmod 4755 \"\(helperPath)\""
        ]
        return await runPrivileged(commands)
    }

    static func uninstallHelper() async -> Result {
        return await runPrivileged(["rm -f \"\(helperPath)\""])
    }

    static func run(_ command: String) async -> Result {
        log.info("[Shell] run: \(command)")
        let result: Result = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let stdout = Pipe()
                let stderr = Pipe()

                process.executableURL = URL(fileURLWithPath: "/bin/bash")
                process.arguments = ["-c", command]
                process.standardOutput = stdout
                process.standardError = stderr

                do {
                    try process.run()
                    process.waitUntilExit()

                    let outData = stdout.fileHandleForReading.readDataToEndOfFile()
                    let errData = stderr.fileHandleForReading.readDataToEndOfFile()

                    let result = Result(
                        exitCode: process.terminationStatus,
                        output: String(data: outData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                        error: String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    )
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(returning: Result(exitCode: -1, output: "", error: error.localizedDescription))
                }
            }
        }
        log.info("[Shell] exit=\(result.exitCode) stdout=\(result.output.prefix(500)) stderr=\(result.error.prefix(500))")
        return result
    }

    static func runPrivileged(_ commands: [String]) async -> Result {
        let joined = commands.joined(separator: " ; ")
        log.info("[Shell] runPrivileged commands: \(joined)")

        let escaped = joined
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let script = """
        osascript -e 'do shell script "\(escaped)" with administrator privileges'
        """
        log.info("[Shell] runPrivileged final script: \(script)")
        return await run(script)
    }
}
