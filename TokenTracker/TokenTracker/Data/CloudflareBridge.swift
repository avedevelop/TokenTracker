import WebKit
import AppKit

/// Bypasses Cloudflare Bot Management on claude.ai by running API calls inside a WKWebView.
/// URLSession requests are blocked by CF managed challenge (requires JavaScript execution).
/// WKWebView resolves CF challenges natively and maintains cf_clearance for subsequent fetches.
@MainActor
final class CloudflareBridge: NSObject, WKNavigationDelegate {
    static let shared = CloudflareBridge()

    private var webView: WKWebView?
    private var hiddenWindow: NSWindow?
    private var loadedKey: String?
    private var setupContinuation: CheckedContinuation<Void, Error>?
    private(set) var isReady = false

    // Ensures the bridge is loaded with the given session key.
    // No-ops when key matches and page is already ready.
    func ensureSession(_ sessionKey: String) async throws {
        if sessionKey == loadedKey, isReady { return }
        isReady = false
        loadedKey = sessionKey

        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.nonPersistent()

        // Full-size frame in a real offscreen window — CF managed challenge inspects viewport/layout
        let wv = WKWebView(frame: NSRect(x: 0, y: 0, width: 1280, height: 800), configuration: config)
        wv.navigationDelegate = self
        webView = wv

        let win = NSWindow(
            contentRect: NSRect(x: -5000, y: -5000, width: 1280, height: 800),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.contentView?.addSubview(wv)
        win.orderFront(nil)
        hiddenWindow = win

        let cookie = HTTPCookie(properties: [
            .name: "sessionKey",
            .value: sessionKey,
            .domain: ".claude.ai",
            .path: "/",
            .secure: "TRUE",
            .sameSitePolicy: HTTPCookieStringPolicy.sameSiteLax
        ])!

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            setupContinuation = cont
            wv.configuration.websiteDataStore.httpCookieStore.setCookie(cookie) { [weak wv] in
                wv?.load(URLRequest(url: URL(string: "https://claude.ai")!))
            }
        }
    }

    // Performs a GET via fetch() inside the authenticated WKWebView context.
    func get(path: String, bearerToken: String? = nil) async throws -> (Int, String) {
        guard let wv = webView, isReady else { throw BridgeError.notReady }

        let authLine = bearerToken.map { ", 'Authorization': 'Bearer \($0)'" } ?? ""
        let js = """
        const r = await fetch('\(path)', {
            credentials: 'include',
            headers: {
                'anthropic-client-platform': 'web_claude_ai',
                'Accept': 'application/json'\(authLine)
            }
        });
        return JSON.stringify({s: r.status, b: await r.text()});
        """

        let result: Any = try await withCheckedThrowingContinuation { cont in
            wv.callAsyncJavaScript(js, arguments: [:], in: nil, in: .page) { res in
                switch res {
                case .success(let val): cont.resume(returning: val as Any)
                case .failure(let err): cont.resume(throwing: err)
                }
            }
        }

        guard let str = result as? String,
              let data = str.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let status = json["s"] as? Int,
              let body = json["b"] as? String
        else { throw BridgeError.parseError }

        return (status, body)
    }

    // MARK: - WKNavigationDelegate

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Ignore Cloudflare challenge pages ("Just a moment...") — they auto-redirect once solved
        webView.evaluateJavaScript("document.title") { [weak self] value, _ in
            let title = value as? String ?? ""
            guard title != "Just a moment..." else { return }
            Task { @MainActor [weak self] in
                self?.isReady = true
                self?.setupContinuation?.resume()
                self?.setupContinuation = nil
            }
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor [weak self] in
            self?.setupContinuation?.resume(throwing: error)
            self?.setupContinuation = nil
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor [weak self] in
            self?.setupContinuation?.resume(throwing: error)
            self?.setupContinuation = nil
        }
    }

    enum BridgeError: Error { case notReady, noResult, parseError }
}
