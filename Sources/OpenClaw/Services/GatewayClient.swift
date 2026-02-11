import Foundation
import Observation

enum ConnectionState: String, Sendable {
    case connected
    case connecting
    case disconnected
}

@MainActor
@Observable
final class GatewayClient {
    private(set) var connectionState: ConnectionState = .disconnected
    private(set) var helloPayload: HelloPayload?

    var onEvent: (@MainActor (String, [String: Any]) -> Void)?

    private let baseURL = "ws://127.0.0.1:18789"
    private let token = "127b26a2b269fe4d29f26d7288bba5c4092ef55c52a6bf20"

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var pendingRequests: [String: CheckedContinuation<Data, any Error>] = [:]
    private var backoffMs: Int = 800
    private var shouldReconnect = true
    private var receiveTask: Task<Void, Never>?
    private var connectSent = false
    private var connectReqId: String?  // track connect request ID separately

    func connect() async {
        shouldReconnect = true
        connectionState = .connecting
        GWLog.log("[GW] connect() called")
        await doConnect()
    }

    func waitForConnection() async -> Bool {
        if connectionState == .connected { return true }
        for i in 0..<20 {
            try? await Task.sleep(for: .milliseconds(500))
            if connectionState == .connected {
                GWLog.log("[GW] waitForConnection: connected after \((i+1)*500)ms")
                return true
            }
        }
        GWLog.log("[GW] waitForConnection: timed out, state=\(connectionState)")
        return false
    }

    func disconnect() {
        shouldReconnect = false
        receiveTask?.cancel()
        receiveTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        connectionState = .disconnected
        flushPending(error: GatewayError.disconnected)
    }

    func request<T: Decodable>(_ method: String, params: (any Encodable)? = nil) async throws -> T {
        guard connectionState == .connected, let ws = webSocketTask else {
            throw GatewayError.notConnected
        }
        let id = UUID().uuidString
        let reqDict = RPCRequest(id: id, method: method, params: params)
        let data = try JSONEncoder().encode(reqDict)
        let text = String(data: data, encoding: .utf8) ?? ""
        try await ws.send(.string(text))

        let responseData: Data = try await withCheckedThrowingContinuation { continuation in
            pendingRequests[id] = continuation
        }

        let wrapper = try JSONDecoder().decode(RPCResponseWrapper<T>.self, from: responseData)
        if wrapper.ok == true, let payload = wrapper.payload {
            return payload
        } else {
            let errMsg = wrapper.error?.message ?? "request failed"
            throw GatewayError.requestFailed(errMsg)
        }
    }

    // MARK: - Private

    private func doConnect() async {
        guard shouldReconnect else { return }
        connectionState = .connecting
        connectSent = false
        connectReqId = nil

        var components = URLComponents(string: baseURL)!
        components.queryItems = [URLQueryItem(name: "token", value: token)]
        let url = components.url!
        GWLog.log("[GW] doConnect: URL = \(url)")

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        let session = URLSession(configuration: config)
        self.urlSession = session
        let task = session.webSocketTask(with: url)
        self.webSocketTask = task
        task.resume()
        GWLog.log("[GW] doConnect: webSocketTask resumed")

        receiveTask = Task {
            await self.receiveLoop()
        }

        // Fallback: if no challenge in 2s, send connect without nonce
        try? await Task.sleep(for: .milliseconds(2000))
        if connectionState != .connected && !connectSent {
            GWLog.log("[GW] doConnect: no challenge, sending connect without nonce")
            await sendConnectFrame(nonce: nil)
        }
    }

    private func receiveLoop() async {
        guard let ws = webSocketTask else { return }
        GWLog.log("[GW] receiveLoop: started")
        while !Task.isCancelled {
            do {
                let message = try await ws.receive()
                let data: Data
                switch message {
                case .data(let d): data = d
                case .string(let s): data = Data(s.utf8)
                @unknown default: continue
                }
                await handleMessage(data)
            } catch {
                GWLog.log("[GW] receiveLoop error: \(error)")
                await handleDisconnect()
                return
            }
        }
    }

    private func handleMessage(_ data: Data) async {
        let rawStr = String(data: data, encoding: .utf8) ?? "<binary>"
        GWLog.log("[GW] RECV: \(rawStr.prefix(300))")

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            GWLog.log("[GW] handleMessage: failed to parse")
            return
        }

        switch type {
        case "event":
            let event = json["event"] as? String ?? ""
            let payload = json["payload"] as? [String: Any] ?? [:]

            if event == "connect.challenge" {
                let nonce = payload["nonce"] as? String
                GWLog.log("[GW] challenge received, nonce=\(nonce ?? "nil")")
                // Fire and forget - don't await the response here!
                // The response will be handled in the "res" case below.
                await sendConnectFrame(nonce: nonce)
            } else {
                onEvent?(event, payload)
            }

        case "res":
            guard let id = json["id"] as? String else { return }
            let ok = json["ok"] as? Bool ?? false

            // Check if this is the connect response
            if id == connectReqId {
                GWLog.log("[GW] connect response: ok=\(ok)")
                if ok {
                    connectionState = .connected
                    backoffMs = 800
                    GWLog.log("[GW] ✅ CONNECTED!")
                    if let payloadDict = json["payload"],
                       let payloadData = try? JSONSerialization.data(withJSONObject: payloadDict),
                       let hello = try? JSONDecoder().decode(HelloPayload.self, from: payloadData) {
                        helloPayload = hello
                        GWLog.log("[GW] hello: version=\(hello.snapshot?.health?.version ?? "?")")
                    }
                } else {
                    let errMsg = (json["error"] as? [String: Any])?["message"] as? String ?? "connect failed"
                    GWLog.log("[GW] ❌ connect rejected: \(errMsg)")
                    await handleDisconnect()
                }
                connectReqId = nil
                return
            }

            // Regular RPC response
            if let continuation = pendingRequests.removeValue(forKey: id) {
                continuation.resume(returning: data)
            }

        default:
            GWLog.log("[GW] unknown type: \(type)")
        }
    }

    /// Send the connect frame. Does NOT wait for response.
    private func sendConnectFrame(nonce: String?) async {
        guard let ws = webSocketTask else { return }
        guard !connectSent else {
            GWLog.log("[GW] sendConnectFrame: already sent, skipping")
            return
        }
        connectSent = true

        let reqId = UUID().uuidString
        connectReqId = reqId

        let connectParams: [String: Any] = [
            "minProtocol": 3,
            "maxProtocol": 3,
            "client": [
                "id": "openclaw-macos",
                "version": "1.0",
                "platform": "macOS",
                "mode": "ui"
            ] as [String: Any],
            "role": "operator",
            "scopes": ["operator.admin", "operator.approvals", "operator.pairing"] as [String],
            "caps": [] as [String],
            "auth": [
                "token": token
            ] as [String: Any]
        ]

        let frame: [String: Any] = [
            "type": "req",
            "id": reqId,
            "method": "connect",
            "params": connectParams
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: frame),
              let text = String(data: data, encoding: .utf8) else {
            GWLog.log("[GW] sendConnectFrame: serialize failed")
            return
        }

        GWLog.log("[GW] SEND connect: \(text.prefix(300))")

        do {
            try await ws.send(.string(text))
            GWLog.log("[GW] sendConnectFrame: sent OK")
        } catch {
            GWLog.log("[GW] sendConnectFrame error: \(error)")
            await handleDisconnect()
        }
    }

    private func handleDisconnect() async {
        GWLog.log("[GW] handleDisconnect")
        connectionState = .disconnected
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        flushPending(error: GatewayError.disconnected)

        guard shouldReconnect else { return }
        let delay = backoffMs
        backoffMs = min(backoffMs * 2, 15000)
        GWLog.log("[GW] reconnecting in \(delay)ms...")
        try? await Task.sleep(for: .milliseconds(delay))
        if shouldReconnect { await doConnect() }
    }

    private func flushPending(error: any Error) {
        let count = pendingRequests.count
        for (_, c) in pendingRequests { c.resume(throwing: error) }
        pendingRequests.removeAll()
        if count > 0 { GWLog.log("[GW] flushed \(count) pending") }
    }
}

// MARK: - RPC Types

private struct RPCRequest: Encodable {
    let type = "req"
    let id: String
    let method: String
    let params: (any Encodable)?

    enum CodingKeys: String, CodingKey {
        case type, id, method, params
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(id, forKey: .id)
        try container.encode(method, forKey: .method)
        if let params {
            try container.encode(AnyEncodable(params), forKey: .params)
        }
    }
}

private struct AnyEncodable: Encodable {
    let value: any Encodable
    init(_ value: any Encodable) { self.value = value }
    func encode(to encoder: any Encoder) throws {
        try value.encode(to: encoder)
    }
}

private struct RPCResponseWrapper<T: Decodable>: Decodable {
    let id: String?
    let ok: Bool?
    let payload: T?
    let error: RPCError?
}

private struct RPCError: Decodable {
    let message: String?
    let code: Int?
}

enum GatewayError: Error, LocalizedError {
    case notConnected
    case disconnected
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConnected: return "未连接到 Gateway"
        case .disconnected: return "与 Gateway 断开连接"
        case .requestFailed(let msg): return msg
        }
    }
}

struct HelloPayload: Decodable {
    let snapshot: HelloSnapshot?

    struct HelloSnapshot: Decodable {
        let health: HealthInfo?
        let sessionDefaults: SessionDefaults?
    }

    struct SessionDefaults: Decodable {
        let mainSessionKey: String?
        let defaultAgentId: String?
    }

    struct HealthInfo: Decodable {
        let version: String?
        let uptime: Double?
        let uptimeMs: Double?
    }
}
