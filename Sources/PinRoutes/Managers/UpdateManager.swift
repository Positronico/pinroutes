import Foundation
import AppKit
import ServiceManagement

@MainActor
final class UpdateManager: ObservableObject {
    @Published var updateAvailable = false
    @Published var latestVersion = ""
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0
    @Published var errorMessage: String?

    private var downloadURL: URL?

    private static let repo = "Positronico/pinroutes"
    private static let apiURL = URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!
    private static let assetName = "PinRoutes.app.zip"

    enum UpdateError: LocalizedError {
        case downloadFailed
        case extractionFailed
        case invalidBundle
        case replaceFailed

        var errorDescription: String? {
            switch self {
            case .downloadFailed: return "Download failed"
            case .extractionFailed: return "Failed to extract update"
            case .invalidBundle: return "Invalid application bundle"
            case .replaceFailed: return "Failed to replace application"
            }
        }
    }

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    // MARK: - Check for Update

    func checkForUpdate() async {
        log.info("[Update] checking for updates (current: \(currentVersion))")

        do {
            var request = URLRequest(url: Self.apiURL)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                log.info("[Update] GitHub API returned non-200 status")
                return
            }

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let remoteVersion = release.tagName.hasPrefix("v")
                ? String(release.tagName.dropFirst())
                : release.tagName

            log.info("[Update] latest release: \(remoteVersion)")

            if Self.isNewer(remote: remoteVersion, local: currentVersion) {
                latestVersion = remoteVersion
                downloadURL = release.assets
                    .first(where: { $0.name == Self.assetName })
                    .flatMap { URL(string: $0.browserDownloadUrl) }
                updateAvailable = true
                log.info("[Update] update available: \(remoteVersion)")
            } else {
                log.info("[Update] already up to date")
            }
        } catch {
            log.info("[Update] check failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Download & Install

    func downloadAndInstall() async {
        guard let downloadURL else {
            errorMessage = "No download URL available"
            return
        }

        guard let host = downloadURL.host,
              host.hasSuffix("github.com") || host.hasSuffix("githubusercontent.com") else {
            errorMessage = "Untrusted download host"
            return
        }

        isDownloading = true
        downloadProgress = 0
        errorMessage = nil

        do {
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("pinroutes-update-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            // Download
            log.info("[Update] downloading from \(downloadURL)")
            let (localURL, response) = try await URLSession.shared.download(for: URLRequest(url: downloadURL))

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw UpdateError.downloadFailed
            }

            let zipPath = tempDir.appendingPathComponent(Self.assetName)
            try FileManager.default.moveItem(at: localURL, to: zipPath)
            downloadProgress = 0.5
            log.info("[Update] downloaded to \(zipPath.path)")

            // Extract
            let extractDir = tempDir.appendingPathComponent("extracted")
            try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)

            let dittoResult = await ShellExecutor.run("/usr/bin/ditto -xk \"\(zipPath.path)\" \"\(extractDir.path)\"")
            guard dittoResult.exitCode == 0 else {
                log.error("[Update] extraction failed: \(dittoResult.error)")
                throw UpdateError.extractionFailed
            }
            downloadProgress = 0.75

            // Validate
            let newAppPath = extractDir.appendingPathComponent("PinRoutes.app")
            let binaryPath = newAppPath.appendingPathComponent("Contents/MacOS/PinRoutes")
            guard FileManager.default.fileExists(atPath: binaryPath.path) else {
                log.error("[Update] invalid bundle: missing binary at \(binaryPath.path)")
                throw UpdateError.invalidBundle
            }
            log.info("[Update] bundle validated")

            // Replace & relaunch
            guard let currentAppPath = Bundle.main.bundleURL.path.removingPercentEncoding else {
                throw UpdateError.replaceFailed
            }

            let pid = ProcessInfo.processInfo.processIdentifier
            let scriptPath = tempDir.appendingPathComponent("update.sh")
            let script = """
            #!/bin/bash
            while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done
            rm -rf "\(currentAppPath)"
            cp -R "\(newAppPath.path)" "\(currentAppPath)"
            open "\(currentAppPath)"
            rm -rf "\(tempDir.path)"
            """

            try script.write(to: scriptPath, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: scriptPath.path
            )

            downloadProgress = 1.0
            log.info("[Update] launching update script and terminating")

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [scriptPath.path]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try process.run()

            try? await SMAppService.mainApp.unregister()
            NSApplication.shared.terminate(nil)
        } catch let error as UpdateError {
            errorMessage = error.errorDescription
            log.error("[Update] failed: \(error.errorDescription ?? "unknown")")
        } catch {
            errorMessage = error.localizedDescription
            log.error("[Update] failed: \(error.localizedDescription)")
        }

        isDownloading = false
    }

    // MARK: - Version Comparison

    static func isNewer(remote: String, local: String) -> Bool {
        let remoteParts = remote.split(separator: ".").compactMap { Int($0) }
        let localParts = local.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(remoteParts.count, localParts.count) {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let l = i < localParts.count ? localParts[i] : 0
            if r > l { return true }
            if r < l { return false }
        }
        return false
    }
}
