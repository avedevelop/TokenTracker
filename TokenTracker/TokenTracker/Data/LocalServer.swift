import Foundation
import Network

final class LocalServer {
    static let port: UInt16 = 51234
    private var listener: NWListener?

    func start() {
        do {
            let parameters = NWParameters.tcp
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: LocalServer.port)!)
            listener?.newConnectionHandler = { [weak self] conn in
                if case .hostPort(let host, _) = conn.endpoint {
                    let h = "\(host)"
                    guard h == "127.0.0.1" || h == "::1" || h.hasPrefix("127.") else {
                        conn.cancel(); return
                    }
                }
                self?.handle(conn)
            }
            listener?.stateUpdateHandler = { _ in }
            listener?.start(queue: .global(qos: .utility))
        } catch {
            // Port already in use or unavailable — silent fail
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .utility))
        connection.receive(minimumIncompleteLength: 1, maximumLength: 2048) { data, _, _, _ in
            guard let data, !data.isEmpty else { connection.cancel(); return }
            let req = String(data: data, encoding: .utf8) ?? ""
            let requestLine = req.split(separator: "\r\n").first.map(String.init) ?? ""

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601

            let body: Data
            if requestLine.hasPrefix("GET /accounts") {
                let manifest = SharedStore.readAccountsManifest()
                body = (try? encoder.encode(manifest)) ?? Data("{}".utf8)
            } else if requestLine.hasPrefix("GET /usage") {
                let usage: UsageData
                if let id = Self.parseAccountId(from: requestLine) {
                    // Explicit account requested (widget AppIntentConfiguration path)
                    usage = SharedStore.readAccount(id: id)
                } else {
                    // No param: serve the widget-selected account (or active if none chosen)
                    let manifest = SharedStore.readAccountsManifest()
                    if let widgetId = manifest.widgetAccountId, widgetId != manifest.activeId {
                        usage = SharedStore.readAccount(id: widgetId)
                    } else {
                        usage = SharedStore.read()
                    }
                }
                body = (try? encoder.encode(usage)) ?? Data()
            } else {
                connection.cancel(); return
            }

            let head = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\n\r\n"
            var response = Data(head.utf8)
            response.append(body)
            connection.send(content: response, completion: .contentProcessed { _ in connection.cancel() })
        }
    }

    /// Extracts the `account=UUID` value from a request line like `GET /usage?account=UUID HTTP/1.1`.
    private static func parseAccountId(from requestLine: String) -> UUID? {
        guard let qIdx = requestLine.firstIndex(of: "?") else { return nil }
        let afterQuery = requestLine[requestLine.index(after: qIdx)...]
        let endIdx = afterQuery.firstIndex(of: " ") ?? afterQuery.endIndex
        let queryString = String(afterQuery[..<endIdx])
        for pair in queryString.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            if parts.count == 2, parts[0] == "account" {
                return UUID(uuidString: parts[1])
            }
        }
        return nil
    }
}
