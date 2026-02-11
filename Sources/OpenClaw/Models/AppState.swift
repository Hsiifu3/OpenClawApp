import Observation

@MainActor
@Observable
final class AppState {
    var selectedPanel: Panel = .chat
    let gateway = GatewayClient()

    var gatewayStatus: ConnectionState {
        gateway.connectionState
    }
}
