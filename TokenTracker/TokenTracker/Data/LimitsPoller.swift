import Foundation

final class LimitsPoller {
    private static let baseURL = "https://claude.ai"
    private static let browserUA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.4 Safari/605.1.15"

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

    func fetchOrgIdFromAPI(auth: AuthMethod) async -> String? {
        let key: String
        switch auth {
        case .cookie(let k): key = k
        case .bearer(let t): key = t
        }
        do {
            try await CloudflareBridge.shared.ensureSession(key)
            let (status, body) = try await CloudflareBridge.shared.get(path: "/api/organizations")
            guard status == 200,
                  let data = body.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let first = json.first else { return nil }
            // API returns numeric "id" and string "uuid" — prefer uuid (the org GUID)
            let orgId = first["uuid"] as? String ?? (first["id"].map { "\($0)" })
            return orgId
        } catch { return nil }
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
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("web_claude_ai", forHTTPHeaderField: "anthropic-client-platform")
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
        var req = URLRequest(url: url)
        req.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("web_claude_ai", forHTTPHeaderField: "anthropic-client-platform")
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
        var req = URLRequest(url: url)
        req.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("web_claude_ai", forHTTPHeaderField: "anthropic-client-platform")
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
        if orgId == nil || orgId!.isEmpty {
            await fetchAndCacheOrgId(sessionKey: sessionKey)
            orgId = UserDefaults.standard.string(forKey: "com.tokentracker.orgId")
        }

        guard let orgId, !orgId.isEmpty else {
            throw PollerError.missingOrgId
        }
        return try await fetchLimits(sessionKey: sessionKey, orgId: orgId)
    }

    /// Variant that takes an explicit orgId. Always uses CloudflareBridge.
    func fetchLimits(sessionKey: String, orgId: String) async throws -> UsageData.Limits {
        guard !orgId.isEmpty else { throw PollerError.missingOrgId }
        return try await fetchLimitsBridge(sessionKey: sessionKey, orgId: orgId)
    }

    private func fetchLimitsBridge(sessionKey: String, orgId: String) async throws -> UsageData.Limits {
        try await CloudflareBridge.shared.ensureSession(sessionKey)
        let (status, body) = try await CloudflareBridge.shared.get(path: "/api/organizations/\(orgId)/usage")
        if status == 401 || status == 403 { throw PollerError.unauthorized }
        guard status == 200 else { throw PollerError.unexpectedResponse }
        guard let data = body.data(using: .utf8) else { throw PollerError.unexpectedResponse }
        return try parseLimits(from: data)
    }

    private func fetchLimitsURLSession(sessionKey: String, orgId: String) async throws -> UsageData.Limits {
        guard let url = URL(string: "\(Self.baseURL)/api/organizations/\(orgId)/usage") else {
            throw PollerError.invalidEndpoint
        }
        var request = URLRequest(url: url)
        request.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")
        request.setValue("web_claude_ai", forHTTPHeaderField: "anthropic-client-platform")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(Self.browserUA, forHTTPHeaderField: "User-Agent")
        request.setValue("https://claude.ai/", forHTTPHeaderField: "Referer")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw PollerError.unexpectedResponse }
        if http.statusCode == 401 || http.statusCode == 403 { throw PollerError.unauthorized }
        guard http.statusCode == 200 else { throw PollerError.unexpectedResponse }
        return try parseLimits(from: data)
    }

    /// Fetch limits using Claude Code OAuth token (Bearer auth) — no sessionKey needed.
    func fetchLimitsWithOAuthToken(_ token: String) async throws -> UsageData.Limits {
        var orgId: String? = await MainActor.run { AccountStore.shared.activeOrgId }
        if orgId == nil || orgId!.isEmpty {
            if let fetched = await fetchOrgIdFromAPI(auth: .bearer(token)) {
                await cacheOrgId(fetched)
                orgId = fetched
            }
        }
        guard let orgId, !orgId.isEmpty else { throw PollerError.missingOrgId }
        try await CloudflareBridge.shared.ensureSession(token)
        let (status, body) = try await CloudflareBridge.shared.get(
            path: "/api/organizations/\(orgId)/usage",
            bearerToken: token
        )
        if status == 401 || status == 403 { throw PollerError.unauthorized }
        guard status == 200 else { throw PollerError.unexpectedResponse }
        guard let data = body.data(using: .utf8) else { throw PollerError.unexpectedResponse }
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
