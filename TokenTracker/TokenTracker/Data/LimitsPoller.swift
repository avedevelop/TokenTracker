import Foundation
import WebKit

final class LimitsPoller {
    private static let baseURL = "https://claude.ai"
    private static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Safari/605.1.15"

    /// All cookies captured from the WKWebView login (includes cf_clearance).
    /// Injected into every URLSession request so Cloudflare lets background polling through.
    static var webViewCookies: [HTTPCookie] = []

    enum PollerError: Error {
        case unauthorized
        case invalidEndpoint
        case unexpectedResponse
        case missingOrgId
    }

    /// Reads Claude Code OAuth token from Keychain (no encryption — stored as plain JSON).
    func readClaudeCodeOAuthToken() -> String? {
        guard let oauth = readRawClaudeCodeCredentials(),
              let token = oauth["accessToken"] as? String else { return nil }
        return token
    }

    /// Returns the raw `claudeAiOauth` dictionary from Claude Code's Keychain entry.
    func readRawClaudeCodeCredentials() -> [String: Any]? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let json = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !json.isEmpty,
                  let jsonData = json.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let oauth = obj["claudeAiOauth"] as? [String: Any] else { return nil }
            return oauth
        } catch {
            return nil
        }
    }

    /// Fetches org ID for the given session key via API only.
    private func fetchAndCacheOrgId(sessionKey: String) async {
        if let orgId = await fetchOrgIdFromAPI(auth: .cookie(sessionKey)) {
            await cacheOrgId(orgId)
        }
    }

    private func cacheOrgId(_ orgId: String) async {
        UserDefaults.standard.set(orgId, forKey: "com.tokentracker.orgId")
    }

    enum AuthMethod {
        case cookie(String)
        case bearer(String)
    }

    private func makeRequest(url: URL, auth: AuthMethod) -> URLRequest {
        var req = URLRequest(url: url)
        req.httpShouldHandleCookies = false  // we build the header manually

        switch auth {
        case .cookie(let key):
            // Merge WebView cookies (includes cf_clearance) with our session key.
            // WebView cookies take lower precedence so sessionKey always wins.
            var cookiePairs: [String] = Self.webViewCookies
                .filter { $0.name != "sessionKey" }
                .map { "\($0.name)=\($0.value)" }
            cookiePairs.append("sessionKey=\(key)")
            req.setValue(cookiePairs.joined(separator: "; "), forHTTPHeaderField: "Cookie")

        case .bearer(let token):
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        req.setValue(Self.userAgent,  forHTTPHeaderField: "User-Agent")
        req.setValue("web_claude_ai", forHTTPHeaderField: "anthropic-client-platform")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        return req
    }

    func fetchOrgIdFromAPI(auth: AuthMethod) async -> String? {
        guard let url = URL(string: "https://claude.ai/api/organizations") else { return nil }
        let request = makeRequest(url: url, auth: auth)
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let orgId = json.first?["id"] as? String else { return nil }
        return orgId
    }

    struct UserInfo {
        var email: String?
        var fullName: String?
    }

    func fetchUserInfo(sessionKey: String) async -> UserInfo {
        if let info = await fetchFromAccount(sessionKey: sessionKey) { return info }
        return await fetchFromOrganizations(sessionKey: sessionKey)
    }

    func fetchUserInfoWithOAuth(_ token: String) async -> UserInfo {
        guard let url = URL(string: "https://claude.ai/api/account") else { return UserInfo() }
        let req = makeRequest(url: url, auth: .bearer(token))
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return UserInfo() }
        let email = json["email"] as? String
        let name = json["full_name"] as? String ?? json["name"] as? String
        return UserInfo(email: email, fullName: name)
    }

    private func fetchFromAccount(sessionKey: String) async -> UserInfo? {
        guard let url = URL(string: "https://claude.ai/api/account") else { return nil }
        let req = makeRequest(url: url, auth: .cookie(sessionKey))
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        let email = json["email"] as? String
        let name = json["full_name"] as? String ?? json["name"] as? String
        guard email != nil || name != nil else { return nil }
        return UserInfo(email: email, fullName: name)
    }

    private func fetchFromOrganizations(sessionKey: String) async -> UserInfo {
        guard let url = URL(string: "https://claude.ai/api/organizations") else { return UserInfo() }
        let req = makeRequest(url: url, auth: .cookie(sessionKey))
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let first = json.first
        else { return UserInfo() }
        let email = first["user_email"] as? String ?? first["email"] as? String
        let name = first["user_name"] as? String ?? first["name"] as? String
        return UserInfo(email: email, fullName: name)
    }

    func fetchLimits(sessionKey: String) async throws -> UsageData.Limits {
        // Prefer the active profile's stored orgId (multi-account safe), fall back to fresh fetch
        var orgId: String? = await MainActor.run { AccountStore.shared.activeOrgId }
        var sessionVerifiedViaFetch = false
        if orgId == nil || orgId!.isEmpty {
            if let fetched = await fetchOrgIdFromAPI(auth: .cookie(sessionKey)) {
                await cacheOrgId(fetched)
                orgId = fetched
                sessionVerifiedViaFetch = true
            } else {
                orgId = UserDefaults.standard.string(forKey: "com.tokentracker.orgId")
            }
        }

        guard let orgId, !orgId.isEmpty else {
            throw PollerError.missingOrgId
        }
        do {
            return try await fetchLimits(sessionKey: sessionKey, orgId: orgId)
        } catch PollerError.unauthorized where sessionVerifiedViaFetch {
            // Session is confirmed valid (orgId just fetched), but usage endpoint rejected us —
            // plan doesn't expose usage data. Log in without limit info.
            throw PollerError.unexpectedResponse
        }
    }

    /// Variant that takes an explicit orgId (used when polling non-active accounts).
    func fetchLimits(sessionKey: String, orgId: String) async throws -> UsageData.Limits {
        guard !orgId.isEmpty else { throw PollerError.missingOrgId }

        guard let url = URL(string: "\(Self.baseURL)/api/organizations/\(orgId)/usage") else {
            throw PollerError.invalidEndpoint
        }

        let request = makeRequest(url: url, auth: .cookie(sessionKey))
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw PollerError.unexpectedResponse
        }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw PollerError.unauthorized
        }
        guard http.statusCode == 200 else {
            throw PollerError.unexpectedResponse
        }

        return try parseLimits(from: data)
    }

    /// Fetch limits using Claude Code OAuth token (Bearer auth) — no sessionKey needed.
    func fetchLimitsWithOAuthToken(_ token: String) async throws -> UsageData.Limits {
        var orgId: String? = await MainActor.run { AccountStore.shared.activeOrgId }
        var sessionVerifiedViaFetch = false
        if orgId == nil || orgId!.isEmpty {
            if let fetched = await fetchOrgIdFromAPI(auth: .bearer(token)) {
                await cacheOrgId(fetched)
                orgId = fetched
                sessionVerifiedViaFetch = true
            }
        }

        guard let orgId, !orgId.isEmpty else {
            throw PollerError.missingOrgId
        }

        guard let url = URL(string: "\(Self.baseURL)/api/organizations/\(orgId)/usage") else {
            throw PollerError.invalidEndpoint
        }

        let request = makeRequest(url: url, auth: .bearer(token))
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else { throw PollerError.unexpectedResponse }
        if http.statusCode == 401 || http.statusCode == 403 {
            if sessionVerifiedViaFetch { throw PollerError.unexpectedResponse }
            throw PollerError.unauthorized
        }
        guard http.statusCode == 200 else { throw PollerError.unexpectedResponse }

        return try parseLimits(from: data)
    }

    /// Variant that takes an explicit orgId for OAuth tokens.
    func fetchLimitsWithOAuthToken(_ token: String, orgId: String) async throws -> UsageData.Limits {
        guard !orgId.isEmpty else { throw PollerError.missingOrgId }

        guard let url = URL(string: "\(Self.baseURL)/api/organizations/\(orgId)/usage") else {
            throw PollerError.invalidEndpoint
        }

        let request = makeRequest(url: url, auth: .bearer(token))
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else { throw PollerError.unexpectedResponse }
        if http.statusCode == 401 || http.statusCode == 403 { throw PollerError.unauthorized }
        guard http.statusCode == 200 else { throw PollerError.unexpectedResponse }

        return try parseLimits(from: data)
    }

    private func parseLimits(from data: Data) throws -> UsageData.Limits {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PollerError.unexpectedResponse
        }

        let isoParser = ISO8601DateFormatter()
        isoParser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        func utilization(_ key: String) -> Double? {
            guard let obj = json[key] as? [String: Any] else { return nil }
            return obj["utilization"] as? Double
        }

        let fiveHour = (json["five_hour"] as? [String: Any])
        let sevenDay = (json["seven_day"] as? [String: Any])
        let extra = (json["extra_usage"] as? [String: Any])

        return UsageData.Limits(
            fiveHourUtilization: fiveHour?["utilization"] as? Double ?? 0,
            fiveHourResetsAt: {
                guard let str = fiveHour?["resets_at"] as? String else { return nil }
                return isoParser.date(from: str)
            }(),
            weeklyUtilization: sevenDay?["utilization"] as? Double ?? 0,
            weeklyResetsAt: {
                guard let str = sevenDay?["resets_at"] as? String else { return nil }
                return isoParser.date(from: str)
            }(),
            sonnetUtilization: utilization("seven_day_sonnet"),
            opusUtilization: utilization("seven_day_opus"),
            extraUsageUsed: extra?["used_credits"] as? Double,
            extraUsageLimit: extra?["monthly_limit"] as? Double,
            extraUsageEnabled: extra?["is_enabled"] as? Bool ?? false
        )
    }
}
