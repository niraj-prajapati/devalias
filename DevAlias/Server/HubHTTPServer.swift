import Foundation
import Network

/// Unprivileged hub HTTP server on a high port (`NWListener` + minimal HTTP/1.1).
final class HubHTTPServer: @unchecked Sendable {
    enum ServerError: Error, LocalizedError {
        case alreadyRunning
        case notRunning
        case bindFailed(String)

        var errorDescription: String? {
            switch self {
            case .alreadyRunning: return "Hub server is already running"
            case .notRunning: return "Hub server is not running"
            case .bindFailed(let message): return message
            }
        }
    }

    private let queue = DispatchQueue(label: "com.nandroidex.devalias.hub-http")
    private var listener: NWListener?
    private var connections: [ObjectIdentifier: NWConnection] = [:]

    private let stateLock = NSLock()
    private var _servers: [DiscoveredServer] = []
    private var _statusJSON: Data = Data("{}".utf8)
    private var dashboardHTML: String

    var onStateChange: (@Sendable (NWListener.State) -> Void)?
    var onBindFailure: (@Sendable (String) -> Void)?

    init(dashboardHTML: String? = nil) {
        self.dashboardHTML = dashboardHTML ?? Self.loadBundledDashboard()
    }

    var isRunning: Bool {
        queue.sync { listener != nil }
    }

    func updateServers(_ servers: [DiscoveredServer]) {
        stateLock.lock()
        _servers = servers
        stateLock.unlock()
    }

    func updateStatus(alias: String, highPort: Int, lanIP: String?, port80: Bool) {
        var payload: [String: Any] = [
            "alias": alias,
            "highPort": highPort,
            "port80": port80,
            "aliasURL": port80 ? "http://\(alias).local/" : "http://\(alias).local:\(highPort)/",
        ]
        if let lanIP {
            payload["lanIP"] = lanIP
            payload["lanURL"] = port80 ? "http://\(lanIP)/" : "http://\(lanIP):\(highPort)/"
        }
        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            stateLock.lock()
            _statusJSON = data
            stateLock.unlock()
        }
    }

    func start(port: UInt16) throws {
        try queue.sync {
            if listener != nil { throw ServerError.alreadyRunning }

            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            if let tcp = parameters.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
                tcp.version = .any
            }

            let nwPort = NWEndpoint.Port(rawValue: port)!
            let listener: NWListener
            do {
                listener = try NWListener(using: parameters, on: nwPort)
            } catch {
                throw ServerError.bindFailed("Failed to create listener on port \(port): \(error.localizedDescription)")
            }

            listener.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                self.onStateChange?(state)
                switch state {
                case .failed(let error):
                    let message: String
                    if Self.isAddressInUse(error) {
                        message = "Port \(port) is already in use (EADDRINUSE). Choose another high port in Settings."
                    } else {
                        message = "Listener failed: \(error.localizedDescription)"
                    }
                    self.onBindFailure?(message)
                    self.queue.async { self.tearDownLocked() }
                case .cancelled:
                    break
                default:
                    break
                }
            }

            listener.newConnectionHandler = { [weak self] connection in
                self?.accept(connection)
            }

            listener.start(queue: queue)
            self.listener = listener
        }
    }

    func stop() {
        queue.sync {
            tearDownLocked()
        }
    }

    private func tearDownLocked() {
        for (_, connection) in connections {
            connection.cancel()
        }
        connections.removeAll()
        listener?.cancel()
        listener = nil
    }

    private func accept(_ connection: NWConnection) {
        let id = ObjectIdentifier(connection)
        connections[id] = connection
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .failed, .cancelled:
                self.queue.async {
                    self.connections.removeValue(forKey: id)
                }
            default:
                break
            }
        }
        connection.start(queue: queue)

        // Abort hung clients (common cause of phone “Loading…” forever).
        let timeout = DispatchWorkItem { [weak self] in
            connection.cancel()
            self?.queue.async {
                self?.connections.removeValue(forKey: id)
            }
        }
        queue.asyncAfter(deadline: .now() + 2.5, execute: timeout)
        receiveRequest(on: connection, id: id, buffer: Data(), timeout: timeout)
    }

    private func receiveRequest(
        on connection: NWConnection,
        id: ObjectIdentifier,
        buffer: Data,
        timeout: DispatchWorkItem
    ) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if error != nil {
                timeout.cancel()
                connection.cancel()
                return
            }

            var next = buffer
            if let data, !data.isEmpty {
                next.append(data)
            }

            if let request = HTTPRequestParser.parse(next) {
                timeout.cancel()
                let servers = self.snapshotServers()
                let status = self.snapshotStatus()
                let router = HTTPRouter(
                    servers: servers,
                    dashboardHTML: self.dashboardHTML,
                    statusJSON: status
                )
                let response = router.handle(request)
                connection.send(content: response.serialized(), completion: .contentProcessed { _ in
                    connection.cancel()
                })
                return
            }

            if isComplete || next.count > 64 * 1024 {
                timeout.cancel()
                // Best-effort 400 if we got something unparseable.
                if !next.isEmpty {
                    let body = Data("Bad Request\n".utf8)
                    let response = HTTPResponse.text("Bad Request\n", status: 400, reason: "Bad Request")
                    connection.send(content: response.serialized(), completion: .contentProcessed { _ in
                        connection.cancel()
                    })
                    _ = body
                } else {
                    connection.cancel()
                }
                return
            }

            // Incomplete headers — wait for more (until timeout).
            self.receiveRequest(on: connection, id: id, buffer: next, timeout: timeout)
        }
    }

    private func snapshotServers() -> [DiscoveredServer] {
        stateLock.lock()
        defer { stateLock.unlock() }
        return _servers
    }

    private func snapshotStatus() -> Data {
        stateLock.lock()
        defer { stateLock.unlock() }
        return _statusJSON
    }

    private static func isAddressInUse(_ error: NWError) -> Bool {
        if case .posix(let code) = error, code == .EADDRINUSE {
            return true
        }
        return error.localizedDescription.lowercased().contains("address already in use")
    }

    static func loadBundledDashboard() -> String {
        let candidates: [URL?] = [
            Bundle.main.url(forResource: "dashboard", withExtension: "html"),
            Bundle.main.url(forResource: "dashboard", withExtension: "html", subdirectory: "Resources"),
            Bundle.main.url(forResource: "dashboard", withExtension: "html", subdirectory: "Server/Resources"),
        ]
        for case let url? in candidates {
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                return text
            }
        }
        return "<html><body>DevAlias</body></html>\n"
    }
}
