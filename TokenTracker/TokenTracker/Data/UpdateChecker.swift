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

        // Parse DMG download URL from assets
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
        // Fallback: construct URL from tag name convention
        if dmgURL == nil {
            let ver = tag.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
            dmgURL = URL(string: "https://github.com/bvsmma/TokenTracker/releases/download/\(tag)/TokenTracker-\(ver).dmg")
        }

        return true
    }

    /// Downloads the DMG to ~/Downloads and opens it so the user can drag to Applications.
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
                    // Fallback to browser on error
                    if let releaseURL = self.releaseURL { NSWorkspace.shared.open(releaseURL) }
                    NSLog("UpdateChecker download error: \(error)")
                    return
                }
                guard let tmpURL else { return }
                try? FileManager.default.removeItem(at: dest)
                try? FileManager.default.moveItem(at: tmpURL, to: dest)
                // Open the DMG — Finder shows drag-to-Applications UI
                NSWorkspace.shared.open(dest)
            }
        }

        // Track progress
        let observation = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            Task { @MainActor [weak self] in
                self?.downloadProgress = progress.fractionCompleted
            }
        }
        _ = observation // keep alive during download
        task.resume()
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
