import Foundation

@MainActor
final class UpdateChecker {
    static let shared = UpdateChecker()

    private let apiURLString = "https://api.github.com/repos/bvsmma/TokenTracker/releases/latest"

    private(set) var availableVersion: String?
    private(set) var releaseURL: URL?

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
        return true
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
