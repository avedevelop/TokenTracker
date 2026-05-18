import Foundation
import CommonCrypto

final class LimitsPoller {
    private static let baseURL = "https://claude.ai"

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
        guard let json = shell("security find-generic-password -s 'Claude Code-credentials' -w 2>/dev/null")?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !json.isEmpty,
              let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = obj["claudeAiOauth"] as? [String: Any] else { return nil }
        return oauth
    }

    /// Fetches org ID for the given session key via API only (Desktop cookies are per-user and unsafe as fallback).
    private func fetchAndCacheOrgId(sessionKey: String) async {
        if let orgId = await fetchOrgIdFromAPI(auth: .cookie(sessionKey)) {
            await cacheOrgId(orgId)
        }
        // No Desktop fallback — it stores the last logged-in user's org and would contaminate other accounts.
    }

    private func cacheOrgId(_ orgId: String) async {
        UserDefaults.standard.set(orgId, forKey: "com.tokentracker.orgId")
    }

    private enum AuthMethod {
        case cookie(String)
        case bearer(String)
    }

    private func fetchOrgIdFromAPI(auth: AuthMethod) async -> String? {
        guard let url = URL(string: "https://claude.ai/api/organizations") else { return nil }
        var request = URLRequest(url: url)
        switch auth {
        case .cookie(let key): request.setValue("sessionKey=\(key)", forHTTPHeaderField: "Cookie")
        case .bearer(let token): request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("web_claude_ai", forHTTPHeaderField: "anthropic-client-platform")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let orgId = json.first?["id"] as? String else { return nil }
        return orgId
    }

    private func readOrgIdFromClaudeDesktop() -> String? {
        let cookiesPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Claude/Cookies").path
        guard FileManager.default.fileExists(atPath: cookiesPath) else { return nil }

        // Use sqlite3 CLI to avoid linking SQLite directly
        let result = shell("sqlite3 '\(cookiesPath)' \"SELECT hex(encrypted_value) FROM cookies WHERE name='lastActiveOrg' LIMIT 1\"")
        guard let hexStr = result?.trimmingCharacters(in: .whitespacesAndNewlines), !hexStr.isEmpty else { return nil }

        // Decrypt using Claude Safe Storage key from Keychain
        guard let safeKey = shell("security find-generic-password -s 'Claude Safe Storage' -w 2>/dev/null")?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !safeKey.isEmpty else { return nil }

        // Convert hex to Data (skip trailing nibble if odd length)
        var encData = Data()
        let chars = Array(hexStr)
        var i = 0
        while i + 1 < chars.count {
            if let byte = UInt8(String(chars[i...i+1]), radix: 16) { encData.append(byte) }
            i += 2
        }
        guard encData.count > 3 else { return nil }
        encData = encData.dropFirst(3) // Remove v10 prefix

        // PBKDF2-SHA1 key derivation (Chrome/Electron standard)
        guard let aesKey = pbkdf2SHA1(password: safeKey, salt: "saltysalt", iterations: 1003, keyLen: 16) else { return nil }

        // AES-128-CBC decrypt with IV = 16 spaces
        guard let decrypted = aesCBCDecrypt(data: encData, key: aesKey, iv: Data(repeating: 0x20, count: 16)) else { return nil }

        // Extract UUID from decrypted bytes
        let text = decrypted.compactMap { (b: UInt8) -> Character? in
            let c = Character(UnicodeScalar(b))
            return c.isHexDigit || c == "-" ? c : nil
        }
        let str = String(text)
        let uuidPattern = try? NSRegularExpression(pattern: "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}")
        if let match = uuidPattern?.firstMatch(in: str, range: NSRange(str.startIndex..., in: str)),
           let range = Range(match.range, in: str) {
            return String(str[range])
        }
        return nil
    }

    private func shell(_ cmd: String) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", cmd]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        try? task.run()
        task.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
    }

    private func pbkdf2SHA1(password: String, salt: String, iterations: Int, keyLen: Int) -> Data? {
        guard let passData = password.data(using: .utf8),
              let saltData = salt.data(using: .utf8) else { return nil }
        var derivedKey = Data(repeating: 0, count: keyLen)
        let result = derivedKey.withUnsafeMutableBytes { derivedPtr in
            passData.withUnsafeBytes { passPtr in
                saltData.withUnsafeBytes { saltPtr in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passPtr.baseAddress, passData.count,
                        saltPtr.baseAddress, saltData.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1),
                        UInt32(iterations),
                        derivedPtr.baseAddress, keyLen
                    )
                }
            }
        }
        return result == kCCSuccess ? derivedKey : nil
    }

    private func aesCBCDecrypt(data: Data, key: Data, iv: Data) -> Data? {
        let outputSize = data.count + kCCBlockSizeAES128
        var output = [UInt8](repeating: 0, count: outputSize)
        var outLength = 0
        let result = data.withUnsafeBytes { inPtr in
            key.withUnsafeBytes { keyPtr in
                iv.withUnsafeBytes { ivPtr in
                    CCCrypt(
                        CCOperation(kCCDecrypt),
                        CCAlgorithm(kCCAlgorithmAES),
                        CCOptions(kCCOptionPKCS7Padding),
                        keyPtr.baseAddress, key.count,
                        ivPtr.baseAddress,
                        inPtr.baseAddress, data.count,
                        &output, outputSize,
                        &outLength
                    )
                }
            }
        }
        return result == kCCSuccess ? Data(output.prefix(outLength)) : nil
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

    /// Variant that takes an explicit orgId (used when polling non-active accounts).
    func fetchLimits(sessionKey: String, orgId: String) async throws -> UsageData.Limits {
        guard !orgId.isEmpty else { throw PollerError.missingOrgId }

        guard let url = URL(string: "\(Self.baseURL)/api/organizations/\(orgId)/usage") else {
            throw PollerError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")
        request.setValue("web_claude_ai", forHTTPHeaderField: "anthropic-client-platform")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

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
        if orgId == nil || orgId!.isEmpty {
            if let fetched = await fetchOrgIdFromAPI(auth: .bearer(token)) {
                await cacheOrgId(fetched)
                orgId = fetched
            }
        }

        guard let orgId, !orgId.isEmpty else {
            throw PollerError.missingOrgId
        }

        guard let url = URL(string: "\(Self.baseURL)/api/organizations/\(orgId)/usage") else {
            throw PollerError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("web_claude_ai", forHTTPHeaderField: "anthropic-client-platform")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

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
