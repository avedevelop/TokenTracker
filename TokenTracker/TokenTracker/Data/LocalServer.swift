import Foundation
import Network

final class LocalServer {
    static let port: UInt16 = 51234
    private var listener: NWListener?

    func start() {
        do {
            listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: LocalServer.port)!)
            listener?.newConnectionHandler = { [weak self] conn in
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
            guard req.hasPrefix("GET /usage") else { connection.cancel(); return }

            let usage = SharedStore.read()
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let body = (try? encoder.encode(usage)) ?? Data()
            let head = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\n\r\n"
            var response = Data(head.utf8)
            response.append(body)
            connection.send(content: response, completion: .contentProcessed { _ in connection.cancel() })
        }
    }
}
