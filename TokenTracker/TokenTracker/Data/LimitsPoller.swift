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

    /// Reads org ID from Claude Desktop's Cookies SQLite database (no network needed).
    private func fetchAndCacheOrgId(sessionKey: String) async {
        // 1. Read lastActiveOrg cookie from Claude Desktop (decrypted via macOS Keychain)
        if let orgId = readOrgIdFromClaudeDesktop() {
            UserDefaults.standard.set(orgId, forKey: "com.tokentracker.orgId")
            return
        }
        // 2. Try API with session key cookie (Swift URLSession passes Cloudflare)
        if let orgId = await fetchOrgIdFromAPI(auth: .cookie(sessionKey)) {
            UserDefaults.standard.set(orgId, forKey: "com.tokentracker.orgId")
            return
        }
        // 3. Try Claude Code OAuth token as Bearer auth
        if let oauthToken = readClaudeCodeOAuthToken(),
           let orgId = await fetchOrgIdFromAPI(auth: .bearer(oauthToken)) {
            UserDefaults.standard.set(orgId, forKey: "com.tokentracker.orgId")
        }
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

    func fetchLimits(sessionKey: String) async throws -> UsageData.Limits {
        if UserDefaults.standard.string(forKey: "com.tokentracker.orgId") == nil {
            await fetchAndCacheOrgId(sessionKey: sessionKey)
        }

        guard let orgId = UserDefaults.standard.string(forKey: "com.tokentracker.orgId") else {
            throw PollerError.missingOrgId
        }

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
        if UserDefaults.standard.string(forKey: "com.tokentracker.orgId") == nil {
            if let orgId = await fetchOrgIdFromAPI(auth: .bearer(token)) {
                UserDefaults.standard.set(orgId, forKey: "com.tokentracker.orgId")
            }
        }

        guard let orgId = UserDefaults.standard.string(forKey: "com.tokentracker.orgId") else {
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
