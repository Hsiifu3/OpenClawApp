# OpenClaw Pro Control Panel - 项目指导文件

## 项目概述

macOS 原生控制面板应用，用于管理 OpenClaw Gateway。采用 Swift + SwiftUI 构建，目标是替代浏览器访问 Gateway Web UI，提供更好的桌面体验。

## 技术栈

- **语言**: Swift 6.0
- **UI 框架**: SwiftUI (macOS 14+)
- **构建**: Swift Package Manager
- **打包**: 自定义 bundle.sh 脚本 → OpenClaw.app
- **设计风格**: macOS 原生风格（毛玻璃、SF Pro、Apple 配色、深浅主题）

## Gateway API

- **地址**: `http://localhost:18789`
- **Token**: `127b26a2b269fe4d29f26d7288bba5c4092ef55c52a6bf20`
- **认证**: URL query param `?token=<TOKEN>`
- **API 文档**: 参考 `/Users/yachiyo/.npm-global/lib/node_modules/openclaw/docs/` 下的文档

### 通信协议: WebSocket RPC

Gateway **不使用 REST API**，而是通过 WebSocket 进行 JSON-RPC 通信。

**WebSocket 地址**: `ws://localhost:18789`

**连接流程**:
1. 建立 WebSocket 连接
2. 收到 `connect.challenge` 事件（含 nonce）
3. 发送 `connect` 请求（含 token 认证）
4. 收到 hello 响应，连接建立

**请求格式**:
```json
{
  "type": "req",
  "id": "<uuid>",
  "method": "<method-name>",
  "params": { ... }
}
```

**响应格式**:
```json
{
  "type": "res",
  "id": "<uuid>",
  "ok": true,
  "payload": { ... }
}
```

**事件格式** (服务器推送):
```json
{
  "type": "event",
  "event": "<event-name>",
  "payload": { ... }
}
```

### 可用 RPC 方法

**状态与健康**:
- `status` - Gateway 状态
- `health` - 健康检查
- `system-presence` - 在线实例列表
- `last-heartbeat` - 最后心跳信息
- `models.list` - 可用模型列表

**会话管理**:
- `sessions.list` - 会话列表 (params: `{includeGlobal, includeUnknown, activeMinutes, limit}`)
- `sessions.patch` - 修改会话 (params: `{key, label, thinkingLevel, verboseLevel, reasoningLevel}`)
- `sessions.delete` - 删除会话 (params: `{key, deleteTranscript}`)

**聊天**:
- `chat.history` - 聊天历史 (params: `{sessionKey, limit}`)
- `chat.send` - 发送消息 (params: `{sessionKey, message, deliver, idempotencyKey, attachments}`)
- `chat.abort` - 中止生成 (params: `{sessionKey, runId}`)

**代理**:
- `agents.list` - 代理列表
- `agent.identity.get` - 代理身份信息 (params: `{agentId}`)
- `agents.files.list` - 代理文件列表 (params: `{agentId}`)
- `agents.files.get` - 获取代理文件 (params: `{agentId, name}`)
- `agents.files.set` - 设置代理文件 (params: `{agentId, name, content}`)

**技能**:
- `skills.status` - 技能状态 (params: `{agentId}`)
- `skills.update` - 更新技能 (params: `{skillKey, enabled, apiKey}`)
- `skills.install` - 安装技能 (params: `{name, installId, timeoutMs}`)

**定时任务**:
- `cron.status` - Cron 状态
- `cron.list` - 任务列表 (params: `{includeDisabled}`)
- `cron.add` - 添加任务
- `cron.update` - 更新任务 (params: `{id, patch}`)
- `cron.remove` - 删除任务 (params: `{id}`)
- `cron.run` - 手动触发 (params: `{id, mode}`)
- `cron.runs` - 运行历史 (params: `{id, limit}`)

**通道**:
- `channels.status` - 通道状态 (params: `{probe, timeoutMs}`)
- `channels.logout` - 登出通道 (params: `{channel}`)

**节点**:
- `node.list` - 节点列表

**配置**:
- `config.get` - 获取配置
- `config.schema` - 配置 schema
- `config.set` - 设置配置
- `config.apply` - 应用配置

**日志**:
- `logs.tail` - 日志尾部 (params: `{cursor, limit, maxBytes}`)

**设备配对**:
- `device.pair.list` - 配对列表
- `device.pair.approve` - 批准配对
- `device.pair.reject` - 拒绝配对
- `device.token.rotate` - 轮换 token
- `device.token.revoke` - 撤销 token

**执行审批**:
- `exec.approval.resolve` - 解决审批

**更新**:
- `update.run` - 运行更新

### 事件类型 (服务器推送)

- `connect.challenge` - 连接挑战（含 nonce）
- `agent` - 代理事件
- `chat` - 聊天流事件 (delta/final/aborted/error)
- `presence` - 在线状态变更
- `cron` - 定时任务事件
- `device.pair.requested` - 设备配对请求
- `device.pair.resolved` - 设备配对完成
- `exec.approval.requested` - 执行审批请求
- `exec.approval.resolved` - 执行审批完成

## 项目结构

```
OpenClawApp/
├── Package.swift              # SPM 配置 (macOS 14+)
├── Info.plist                 # App bundle 配置
├── Makefile                   # build / app / run / clean
├── scripts/
│   └── bundle.sh              # 打包为 .app 并 codesign
├── Sources/OpenClaw/
│   ├── OpenClawApp.swift      # @main 入口，WindowGroup + hiddenTitleBar
│   ├── Models/
│   │   ├── AppState.swift     # @Observable 全局状态 (selectedPanel, gatewayStatus)
│   │   └── Panel.swift        # 11 个面板枚举 (chat/overview/channels/sessions/cronJobs/agents/skills/nodes/config/debug/logs)
│   └── Views/
│       ├── ContentView.swift  # NavigationSplitView (sidebar + detail)
│       ├── SidebarView.swift  # 侧边栏：4 个 Section (通用/管理/连接/系统)
│       └── WebView.swift      # WKWebView 封装，CSS 注入隐藏原生侧边栏
└── OpenClaw.app/              # 编译产物
```

## 当前状态 (Phase 1 ✅ 完成)

Phase 1 是 MVP：原生 App 壳 + WebView 嵌入 Gateway Web UI。

### 已完成
- [x] SwiftUI App 框架 (hiddenTitleBar, 1200x800)
- [x] NavigationSplitView 布局（原生侧边栏 + WebView 详情区）
- [x] 11 个面板定义（中英文名称、SF Symbol 图标、路由路径）
- [x] WKWebView 封装（URL 导航、CSS 注入隐藏 Gateway 原生侧边栏）
- [x] Gateway 状态指示灯（绿/黄/红）
- [x] App bundle 打包脚本 + codesign
- [x] 编译通过，可运行

### Phase 1 遗留问题
- [ ] Gateway 状态检测未实现（目前硬编码为 .disconnected）
- [ ] 没有 App 图标
- [ ] 深色/浅色主题未适配
- [ ] WebView 加载状态无反馈

---

## Phase 2: 原生化 (当前阶段)

**目标**: 将关键面板从 WebView 替换为原生 SwiftUI 视图，通过 Gateway REST API 获取数据。

### 2.1 基础设施

#### WebSocket RPC Client
创建 `Services/GatewayClient.swift`：
- 基于 `URLSessionWebSocketTask` 实现 WebSocket 连接
- JSON-RPC 请求/响应匹配（通过 UUID id）
- 服务器推送事件处理（chat stream、presence、cron 等）
- connect 握手：challenge → connect(token) → hello
- 自动重连 + 指数退避
- async/await API
- 错误处理

#### Gateway 状态检测
- WebSocket 连接状态即为 Gateway 状态
- 连接成功 → .connected，断开 → .disconnected，重连中 → .connecting
- 更新 `AppState.gatewayStatus`
- 侧边栏状态灯联动

#### 数据模型
在 `Models/` 下创建对应 Gateway 返回数据的 Swift 结构体。

### 2.2 原生面板（按优先级）

#### P0 - 概览 (Overview)
- Gateway 运行状态、版本、uptime
- 当前模型、token 用量
- 活跃会话数、代理数
- 最近活动摘要
- **设计**: 卡片式布局，类似 macOS 系统信息

#### P1 - 会话 (Sessions)
- 会话列表（活跃/历史）
- 每个会话：模型、token 用量、最后消息时间
- 点击查看会话详情/历史消息
- **设计**: 类似 Mail.app 的列表+详情

#### P2 - 代理 (Agents)
- 代理列表 + 状态
- 代理配置查看
- **设计**: 卡片网格

#### P3 - 定时任务 (Cron Jobs)
- 任务列表 + 状态（启用/禁用）
- 下次执行时间
- 手动触发按钮
- 运行历史
- **设计**: 表格式

#### P4 - 其他面板
- 通道 (Channels): 已连接通道列表 + 状态
- 技能 (Skills): 已安装技能列表
- 节点 (Nodes): 已配对节点 + 在线状态
- 配置 (Config): Gateway 配置查看/编辑（JSON 编辑器）
- 日志 (Logs): 实时日志流（WebSocket 或轮询）

#### 保留 WebView 的面板
- **对话 (Chat)**: 交互复杂，保留 WebView
- **调试 (Debug)**: 保留 WebView

### 2.3 设计规范

#### 配色
```
主色调: 系统蓝 (.blue)
背景: .background (自动适配深浅)
卡片: .regularMaterial (毛玻璃)
文字: .primary / .secondary / .tertiary
状态: .green (在线) / .yellow (连接中) / .red (离线)
```

#### 字体
```
标题: .title2 + .semibold
副标题: .headline
正文: .body
辅助: .caption + .secondary
等宽: .monospaced (代码/ID/JSON)
```

#### 间距
```
卡片内边距: 16
卡片间距: 12
Section 间距: 20
```

#### 组件
- 使用 `GroupBox` 做卡片
- 使用 `.material` 做毛玻璃效果
- 状态指示用 `Circle().fill(color).frame(width: 8, height: 8)`
- 加载状态用 `ProgressView()`

---

## Phase 3: 增强功能 (未来)

- 财经数据面板（贵金属/加密货币/美股）
- AI 新闻聚合面板
- 系统通知集成（macOS Notification Center）
- 菜单栏快捷入口（MenuBarExtra）
- 全局快捷键
- PWA 支持（可选）

---

## 开发指南

### 构建 & 运行
```bash
cd /Users/yachiyo/.openclaw/workspace/OpenClawApp

# 构建
make build

# 打包并运行
make run

# 清理
make clean
```

### 添加新面板
1. 如果是原生面板，在 `Views/` 下创建 `XxxView.swift`
2. 在 `ContentView.swift` 的 detail 区域添加条件判断：
   - 原生面板 → 显示 SwiftUI View
   - WebView 面板 → 显示 WebView
3. 更新 `Panel.swift` 的 `isWeb` 属性

### 添加新 API 调用
1. 在 `Services/GatewayAPI.swift` 添加方法
2. 在 `Models/` 下创建对应数据模型
3. 在 View 中使用 `.task {}` 加载数据

### 代码风格
- Swift 6.0 严格并发 (Sendable)
- @Observable 替代 ObservableObject
- async/await 替代 Combine
- 中文注释，英文代码

---

## 重要约束

1. **macOS 14+ only** — 可以使用最新 SwiftUI API
2. **不使用第三方依赖** — 纯 Apple 框架
3. **Gateway token 不要硬编码** — 后续应从配置文件或环境变量读取
4. **所有网络请求必须异步** — 不阻塞 UI
5. **支持深色/浅色模式** — 使用系统语义颜色

---

## Codex 开发指令

当使用 Codex 执行开发任务时，使用以下模板：

```bash
/Users/yachiyo/.npm-global/bin/codex exec \
  --skip-git-repo-check \
  --sandbox workspace-write \
  --output-last-message /tmp/openclaw-app-output.txt \
  "参考 /Users/yachiyo/.openclaw/workspace/OpenClawApp/PROJECT.md 中的项目指导，执行以下任务：<具体任务描述>"
```

### 任务拆分建议（Phase 2）

**Task 1**: 创建 WebSocket RPC Client + 数据模型
- 创建 `Services/GatewayClient.swift` — WebSocket 连接管理
- 实现 JSON-RPC 请求/响应/事件处理
- 实现 connect 握手流程（challenge → connect → hello）
- Token 认证
- 自动重连 + 指数退避
- 创建 `Models/` 下的数据模型（Status, Session, Agent, CronJob 等）

**Task 2**: 实现 Gateway 状态检测 + 概览面板
- 连接成功后调用 `status` + `health` + `models.list`
- 更新 `AppState.gatewayStatus` 为实时状态
- 侧边栏状态灯联动
- 创建 `OverviewView.swift` — 显示 Gateway 状态、版本、模型、会话数等

**Task 3**: 实现会话面板 (SessionsView)
- 调用 `sessions.list` 获取会话列表
- 会话列表 + 详情（模型、token 用量、最后消息时间）
- 调用 `chat.history` 查看消息历史

**Task 4**: 实现代理面板 (AgentsView) + 定时任务面板 (CronView)
- 代理：`agents.list` + `agent.identity.get`
- 定时任务：`cron.list` + `cron.status` + `cron.runs`
- 手动触发按钮（`cron.run`）

**Task 5**: 实现其他原生面板
- 通道 (Channels): `channels.status`
- 技能 (Skills): `skills.status`
- 节点 (Nodes): `node.list`

**Task 6**: 配置面板 + 日志面板
- 配置：`config.get` + `config.schema` + `config.apply`
- 日志：`logs.tail` 轮询实现实时日志流

**Task 7**: 打磨 UI
- App 图标
- 深浅主题适配
- 动画和过渡效果
- 加载状态和错误处理
- WebSocket 事件驱动的实时更新
