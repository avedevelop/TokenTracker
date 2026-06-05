import SwiftUI
import WebKit

// Embeds a real WebKit browser so Cloudflare challenges are solved automatically.
// After the user is logged in the view polls for the sessionKey cookie, copies ALL
// claude.ai cookies into LimitsPoller.webViewCookies so URLSession requests can
// include cf_clearance and pass Cloudflare checks during background polling.
struct ClaudeWebAuthView: NSViewRepresentable {
    let onTokenFound: (String) -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        if let url = URL(string: "https://claude.ai") {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onTokenFound: onTokenFound) }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let onTokenFound: (String) -> Void
        weak var webView: WKWebView?
        private var pollTimer: Timer?

        init(onTokenFound: @escaping (String) -> Void) {
            self.onTokenFound = onTokenFound
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            startPolling()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            startPolling()
        }

        private func startPolling() {
            pollTimer?.invalidate()
            pollTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
                self?.checkForSessionKey()
            }
        }

        private func checkForSessionKey() {
            WKWebsiteDataStore.default().httpCookieStore.getAllCookies { [weak self] cookies in
                let claudeCookies = cookies.filter { $0.domain.contains("claude.ai") }
                guard let token = claudeCookies.first(where: { $0.name == "sessionKey" })?.value
                else { return }

                // Snapshot all claude.ai cookies so URLSession polling can include them
                LimitsPoller.webViewCookies = claudeCookies

                DispatchQueue.main.async {
                    self?.pollTimer?.invalidate()
                    self?.onTokenFound(token)
                }
            }
        }

        deinit { pollTimer?.invalidate() }
    }
}
