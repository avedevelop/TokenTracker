import AppKit
import WebKit

// Opens a standalone NSWindow with a real WebKit browser.
// Cloudflare challenges are solved automatically by WebKit.
// When sessionKey is detected the window closes and calls back with the token
// plus all claude.ai cookies (including cf_clearance) for URLSession polling.
final class WebAuthWindowController: NSWindowController, WKNavigationDelegate, NSWindowDelegate {
    private var onTokenFound: (String) -> Void = { _ in }
    private var webView: WKWebView!
    private var pollTimer: Timer?
    private var done = false

    // Retained so ARC doesn't deallocate the controller while the window is open
    private static var current: WebAuthWindowController?

    static func open(onTokenFound: @escaping (String) -> Void) {
        let controller = WebAuthWindowController()
        controller.onTokenFound = onTokenFound
        current = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    override func loadWindow() {
        let config = WKWebViewConfiguration()
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 960, height: 680), configuration: config)
        webView.navigationDelegate = self

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 680),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.title = "Sign in to Claude.ai"
        win.contentView = webView
        win.center()
        win.delegate = self
        self.window = win

        if let url = URL(string: "https://claude.ai") {
            webView.load(URLRequest(url: url))
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        startPolling()
    }

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkForToken()
        }
    }

    private func checkForToken() {
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self, !self.done else { return }
            let claudeCookies = cookies.filter { $0.domain.contains("claude.ai") }
            guard let token = claudeCookies.first(where: { $0.name == "sessionKey" })?.value
            else { return }

            self.done = true
            self.pollTimer?.invalidate()

            // Store all cookies so URLSession polling can pass Cloudflare
            LimitsPoller.webViewCookies = claudeCookies

            let callback = self.onTokenFound
            DispatchQueue.main.async {
                self.window?.close()
                WebAuthWindowController.current = nil
                callback(token)
            }
        }
    }

    func windowWillClose(_ notification: Notification) {
        pollTimer?.invalidate()
        WebAuthWindowController.current = nil
    }

    deinit { pollTimer?.invalidate() }
}
