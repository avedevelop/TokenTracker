import Foundation
import AppKit
import Combine

@MainActor
final class UpdateChecker {
    static let shared = UpdateChecker()

    private let apiURLString = "https://api.github.com/repos/bvsmma/TokenTracker/releases/latest"

    private(set) var availableVersion: String?
    private(set) var releaseURL: URL?
    private(set) var dmgURL: URL?

    @Published var isDownloading = false
    @Published var isInstalling = false
    @Published var downloadProgress: Double = 0

    func check() async -> Bool {
        guard let apiURL = URL(string: apiURLString) else { return false }
        var request = URLRequest(url: apiURL)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String,
              let html = json["html_url"] as? String,
              let url = URL(string: html) else { return false }

        let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        guard isNewer(tag, than: current) else { return false }

        availableVersion = tag
        releaseURL = url

        if let assets = json["assets"] as? [[String: Any]] {
            for asset in assets {
                if let name = asset["name"] as? String,
                   name.hasSuffix(".dmg"),
                   let downloadURL = asset["browser_download_url"] as? String,
                   let dmg = URL(string: downloadURL) {
                    dmgURL = dmg
                    break
                }
            }
        }
        if dmgURL == nil {
            let ver = tag.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
            dmgURL = URL(string: "https://github.com/bvsmma/TokenTracker/releases/download/\(tag)/TokenTracker-\(ver).dmg")
        }
        return true
    }

    /// Downloads DMG, mounts it silently, copies app over itself via a detached shell script, then quits.
    func downloadAndOpen() {
        guard let dmgURL else {
            if let releaseURL { NSWorkspace.shared.open(releaseURL) }
            return
        }
        isDownloading = true
        downloadProgress = 0

        let dest = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads")
            .appendingPathComponent(dmgURL.lastPathComponent)

        let session = URLSession(configuration: .default, delegate: nil, delegateQueue: nil)
        let task = session.downloadTask(with: dmgURL) { [weak self] tmpURL, _, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isDownloading = false
                self.downloadProgress = 0

                if let error {
                    if let releaseURL = self.releaseURL { NSWorkspace.shared.open(releaseURL) }
                    NSLog("UpdateChecker download error: \(error)")
                    return
                }
                guard let tmpURL else { return }
                try? FileManager.default.removeItem(at: dest)
                try? FileManager.default.moveItem(at: tmpURL, to: dest)

                self.isInstalling = true
                self.installFromDMG(at: dest)
            }
        }

        let observation = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            Task { @MainActor [weak self] in self?.downloadProgress = progress.fractionCompleted }
        }
        _ = observation
        task.resume()
    }

    // MARK: - Private: mount → copy → relaunch

    private func installFromDMG(at dmgPath: URL) {
        let currentAppPath = Bundle.main.bundleURL.path

        // Mount DMG silently, parse mount point from hdiutil output
        let mountOutput = shell("hdiutil attach '\(dmgPath.path)' -nobrowse -noautoopen 2>&1")
        guard let mountPoint = parseMountPoint(from: mountOutput ?? "") else {
            // Fallback: open DMG in Finder so user can drag manually
            NSWorkspace.shared.open(dmgPath)
            return
        }

        let newAppPath = mountPoint + "/TokenTracker.app"
        guard FileManager.default.fileExists(atPath: newAppPath) else {
            NSWorkspace.shared.open(dmgPath)
            return
        }

        // Write a detached shell script that:
        // 1. waits for this process to exit
        // 2. copies the new .app over the old location
        // 3. removes quarantine
        // 4. relaunches from the same path
        // 5. detaches the DMG volume
        let scriptPath = NSTemporaryDirectory() + "tokentracker_updater.sh"
        let pid = ProcessInfo.processInfo.processIdentifier
        let script = """
        #!/bin/bash
        # Wait for old process to quit
        while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done
        sleep 0.3
        # Replace app
        rm -rf '\(currentAppPath)'
        cp -R '\(newAppPath)' '\(currentAppPath)'
        xattr -dr com.apple.quarantine '\(currentAppPath)' 2>/dev/null
        # Relaunch
        open '\(currentAppPath)'
        # Detach DMG
        hdiutil detach '\(mountPoint)' -force 2>/dev/null
        # Self-clean
        rm -f '\(scriptPath)'
        """

        try? script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath)

        // Remember current version so new launch can show "Updated to vX.X.X"
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        UserDefaults.standard.set(currentVersion, forKey: "com.tokentracker.previousVersion")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptPath]
        try? process.run()

        NSApp.terminate(nil)
    }

    private func parseMountPoint(from output: String) -> String? {
        // hdiutil attach prints lines like: /dev/disk4s1  Apple_HFS  /Volumes/TokenTracker 1.3.0
        for line in output.components(separatedBy: "\n") {
            let parts = line.components(separatedBy: "\t")
            if let last = parts.last?.trimmingCharacters(in: .whitespaces),
               last.hasPrefix("/Volumes/") {
                return last
            }
        }
        return nil
    }

    private func shell(_ cmd: String) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", cmd]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        try? task.run()
        task.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
    }

    private func isNewer(_ remote: String, than current: String) -> Bool {
        let clean = { (v: String) in v.trimmingCharacters(in: CharacterSet(charactersIn: "v")) }
        let r = clean(remote).split(separator: ".").compactMap { Int($0) }
        let c = clean(current).split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(r.count, c.count) {
            let rv = i < r.count ? r[i] : 0
            let cv = i < c.count ? c[i] : 0
            if rv != cv { return rv > cv }
        }
        return false
    }
}
