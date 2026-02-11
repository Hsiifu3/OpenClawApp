import Foundation

// MARK: - Status

struct StatusResponse: Decodable {
    let version: String?
    let uptime: Double?
    let uptimeMs: Double?
    let platform: String?
    let nodeVersion: String?
    let configPath: String?
}

// MARK: - Health

struct HealthResponse: Decodable {
    let version: String?
    let uptime: Double?
    let uptimeMs: Double?
    let ok: Bool?
}

// MARK: - Models

struct ModelsListResponse: Decodable {
    let models: [ModelInfo]?
}

struct ModelInfo: Decodable, Identifiable {
    let id: String?
    let provider: String?
    let model: String?
    let displayName: String?

    var stableId: String { id ?? model ?? UUID().uuidString }

    enum CodingKeys: String, CodingKey {
        case id, provider, model, displayName
    }
}

// MARK: - Sessions

struct SessionsListResponse: Decodable {
    let sessions: [SessionInfo]?
}

struct SessionInfo: Decodable, Identifiable {
    let key: String?
    let label: String?
    let agentId: String?
    let model: String?
    let kind: String?
    let lastActiveAt: Double?
    let lastActiveAtMs: Double?
    let createdAt: Double?
    let createdAtMs: Double?
    let totalTokens: Int?
    let contextTokens: Int?

    var id: String { key ?? UUID().uuidString }
}

// MARK: - Agents

struct AgentsListResponse: Decodable {
    let agents: [AgentInfo]?
    let defaultId: String?
}

struct AgentInfo: Decodable, Identifiable {
    let id: String
    let name: String?
    let displayName: String?
    let model: AgentModel?
    let workspace: String?

    struct AgentModel: Decodable {
        let primary: String?
    }
}

struct AgentIdentity: Decodable {
    let agentId: String?
    let name: String?
    let avatar: String?
    let emoji: String?
}

// MARK: - Cron

struct CronStatusResponse: Decodable {
    let running: Bool?
    let jobCount: Int?
    let nextRunAtMs: Double?
}

struct CronListResponse: Decodable {
    let jobs: [CronJobInfo]?
}

struct CronJobInfo: Decodable, Identifiable {
    let id: String
    let name: String?
    let description: String?
    let enabled: Bool?
    let schedule: CronSchedule?
    let sessionTarget: String?
    let payload: CronPayload?
    let state: CronState?

    struct CronSchedule: Decodable {
        let kind: String?
        let expr: String?
        let tz: String?
        let everyMs: Double?
        let at: String?
    }

    struct CronPayload: Decodable {
        let kind: String?
        let text: String?
        let message: String?
    }

    struct CronState: Decodable {
        let lastStatus: String?
        let lastRunAtMs: Double?
        let nextRunAtMs: Double?
        let runCount: Int?
    }
}

// MARK: - Channels

struct ChannelsStatusResponse: Decodable {
    let channelOrder: [String]?
    let channelAccounts: [String: [ChannelAccount]]?

    struct ChannelAccount: Decodable {
        let accountId: String?
        let connected: Bool?
        let running: Bool?
        let configured: Bool?
        let enabled: Bool?
        let error: String?
    }
}

// MARK: - Nodes

struct NodeListResponse: Decodable {
    let nodes: [NodeInfo]?
}

struct NodeInfo: Decodable, Identifiable {
    let id: String?
    let name: String?
    let displayName: String?
    let platform: String?
    let connected: Bool?
    let lastSeenAt: Double?
    let lastSeenAtMs: Double?
    let capabilities: [String]?

    var stableId: String { id ?? name ?? UUID().uuidString }
}

// MARK: - Chat

struct ChatHistoryResponse: Decodable {
    let messages: [ChatMessage]?
    let thinkingLevel: String?
}

struct ChatMessage: Decodable, Identifiable {
    let role: String?
    let content: ChatContent?
    let timestamp: Double?
    let id: String?

    var stableId: String { id ?? UUID().uuidString }

    enum CodingKeys: String, CodingKey {
        case role, content, timestamp, id
    }

    // content 可能是 string 或 array
    enum ChatContent: Decodable {
        case text(String)
        case parts([ChatPart])

        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let str = try? container.decode(String.self) {
                self = .text(str)
                return
            }
            if let parts = try? container.decode([ChatPart].self) {
                self = .parts(parts)
                return
            }
            self = .text("")
        }

        var textValue: String {
            switch self {
            case .text(let s): return s
            case .parts(let parts):
                return parts.compactMap { $0.text }.joined()
            }
        }
    }

    struct ChatPart: Decodable {
        let type: String?
        let text: String?
    }
}

// MARK: - Cron Runs

struct CronRunsResponse: Decodable {
    let runs: [CronRun]?
}

struct CronRun: Decodable, Identifiable {
    let id: String
    let status: String?
    let startedAtMs: Double?
    let finishedAtMs: Double?
    let durationMs: Double?
    let error: String?
}

// MARK: - Config Set/Apply

struct ConfigSetResponse: Decodable {
    let ok: Bool?
    let hash: String?
}

struct ConfigApplyResponse: Decodable {
    let ok: Bool?
}

// MARK: - Logs

struct LogsTailResponse: Decodable {
    let lines: [String]?
    let cursor: Int?
    let file: String?
    let truncated: Bool?
    let reset: Bool?
}
