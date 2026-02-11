import Foundation

enum Panel: String, CaseIterable, Identifiable {
    case chat
    case overview
    case channels
    case sessions
    case cronJobs
    case agents
    case skills
    case nodes
    case config
    case debug
    case logs

    var id: String { rawValue }

    /// 中文名称
    var titleZH: String {
        switch self {
        case .chat: return "对话"
        case .overview: return "概览"
        case .channels: return "通道"
        case .sessions: return "会话"
        case .cronJobs: return "定时任务"
        case .agents: return "代理"
        case .skills: return "技能"
        case .nodes: return "节点"
        case .config: return "配置"
        case .debug: return "调试"
        case .logs: return "日志"
        }
    }

    /// 英文名称（技术术语保留）
    var titleEN: String {
        switch self {
        case .chat: return "Chat"
        case .overview: return "Overview"
        case .channels: return "Channels"
        case .sessions: return "Sessions"
        case .cronJobs: return "Cron Jobs"
        case .agents: return "Agents"
        case .skills: return "Skills"
        case .nodes: return "Nodes"
        case .config: return "Config"
        case .debug: return "Debug"
        case .logs: return "Logs"
        }
    }

    var icon: String {
        switch self {
        case .chat: return "bubble.left.and.bubble.right"
        case .overview: return "rectangle.grid.2x2"
        case .channels: return "point.3.connected.trianglepath.dotted"
        case .sessions: return "clock.arrow.circlepath"
        case .cronJobs: return "calendar.badge.clock"
        case .agents: return "person.2"
        case .skills: return "sparkles"
        case .nodes: return "circle.grid.cross"
        case .config: return "gearshape"
        case .debug: return "ladybug"
        case .logs: return "doc.text.magnifyingglass"
        }
    }

    var path: String {
        switch self {
        case .chat: return "/chat"
        case .overview: return "/overview"
        case .channels: return "/channels"
        case .sessions: return "/sessions"
        case .cronJobs: return "/cron"
        case .agents: return "/agents"
        case .skills: return "/skills"
        case .nodes: return "/nodes"
        case .config: return "/config"
        case .debug: return "/debug"
        case .logs: return "/logs"
        }
    }

    var isWeb: Bool {
        switch self {
        case .overview, .sessions, .agents, .cronJobs,
             .channels, .skills, .nodes, .config, .logs:
            return false
        default:
            return true
        }
    }
}
