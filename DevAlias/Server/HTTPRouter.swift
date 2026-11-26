import Foundation

struct HTTPRequest: Sendable {
    var method: String
    var path: String
    var headers: [String: String]
}

struct HTTPResponse: Sendable {
    var statusCode: Int
    var reason: String
    var headers: [String: String]
    var body: Data

    static func ok(body: Data, contentType: String) -> HTTPResponse {
        HTTPResponse(
            statusCode: 200,
            reason: "OK",
            headers: [
                "Content-Type": contentType,
                "Content-Length": "\(body.count)",
                "Connection": "close",
                "Cache-Control": "no-store",
            ],
            body: body
        )
    }

    static func text(_ string: String, status: Int = 200, reason: String = "OK", contentType: String = "text/plain; charset=utf-8") -> HTTPResponse {
        let data = Data(string.utf8)
        return HTTPResponse(
            statusCode: status,
            reason: reason,
            headers: [
                "Content-Type": contentType,
                "Content-Length": "\(data.count)",
                "Connection": "close",
                "Cache-Control": "no-store",
            ],
            body: data
        )
    }

    static func notFound() -> HTTPResponse {
        text("Not Found", status: 404, reason: "Not Found")
    }

    func serialized() -> Data {
        var header = "HTTP/1.1 \(statusCode) \(reason)\r\n"
        for (key, value) in headers.sorted(by: { $0.key < $1.key }) {
            header += "\(key): \(value)\r\n"
        }
        header += "\r\n"
        var data = Data(header.utf8)
        data.append(body)
        return data
    }
}

enum HTTPRequestParser {
    /// Parses a complete HTTP/1.1 request head (method, path, headers). Body ignored for GET.
    static func parse(_ data: Data) -> HTTPRequest? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        guard let headerEnd = normalized.range(of: "\n\n") else { return nil }
        let head = String(normalized[..<headerEnd.lowerBound])
        let lines = head.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let requestLine = lines.first else { return nil }
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else { return nil }
        let method = String(parts[0])
        var path = String(parts[1])
        if let q = path.firstIndex(of: "?") {
            path = String(path[..<q])
        }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() where !line.isEmpty {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces).lowercased()
            let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            headers[key] = value
        }
        return HTTPRequest(method: method, path: path, headers: headers)
    }
}

/// Maps paths to responses. Snapshot of servers supplied by the hub.
struct HTTPRouter: Sendable {
    var servers: [DiscoveredServer]
    var dashboardHTML: String
    var statusJSON: Data

    init(servers: [DiscoveredServer], dashboardHTML: String, statusJSON: Data = Data("{}".utf8)) {
        self.servers = servers
        self.dashboardHTML = dashboardHTML
        self.statusJSON = statusJSON
    }

    func handle(_ request: HTTPRequest) -> HTTPResponse {
        guard request.method == "GET" || request.method == "HEAD" else {
            return .text("Method Not Allowed", status: 405, reason: "Method Not Allowed")
        }

        switch request.path {
        case "/health":
            return .text("OK\n")
        case "/", "/index.html":
            let data = Data(dashboardHTML.utf8)
            var response = HTTPResponse.ok(body: data, contentType: "text/html; charset=utf-8")
            if request.method == "HEAD" {
                response.body = Data()
            }
            return response
        case "/api/status":
            var response = HTTPResponse.ok(body: statusJSON, contentType: "application/json; charset=utf-8")
            if request.method == "HEAD" {
                response.body = Data()
            }
            return response
        case "/api/ports":
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys]
                let data = try encoder.encode(servers)
                var response = HTTPResponse.ok(body: data, contentType: "application/json; charset=utf-8")
                if request.method == "HEAD" {
                    response.body = Data()
                }
                return response
            } catch {
                return .text("encode error", status: 500, reason: "Internal Server Error")
            }
        case "/api/events":
            return .text(
                "SSE not enabled in v1 stub — poll GET /api/ports every 3s\n",
                status: 501,
                reason: "Not Implemented"
            )
        default:
            return .notFound()
        }
    }
}
