# OrchAI 参考项目分析与借鉴

## 一、acpx 项目核心借鉴点

### 1.1 ACP 协议实现（✅ 直接使用）

**核心价值**：标准化的 JSON-RPC 2.0 over stdio，避免 PTY 抓取的脆弱性

```typescript
// 可直接使用的组件
import { AcpClient } from 'acpx/src/client.ts';
import { FileSystemHandlers } from 'acpx/src/filesystem.ts';
import { TerminalManager } from 'acpx/src/terminal.ts';
```

**关键特性**：
- ✅ 持久化会话：按 git root 作用域
- ✅ 命名会话：同一仓库并行工作流 (`-s backend`, `-s frontend`)
- ✅ 提示队列：运行中的提示自动排队
- ✅ 协作取消：通过队列 IPC 发送取消信号
- ✅ 软关闭：关闭会话但保留历史记录

### 1.2 Agent 注册表模式（✅ 采用）

```typescript
const AGENT_REGISTRY = {
  claude: "npx -y @zed-industries/claude-agent-acp@^0.21.0",
  opencode: "npx -y opencode-ai acp",
  codex: "npx @zed-industries/codex-acp@^0.9.5",
  cursor: "cursor-agent acp",
  kiro: "kiro-cli acp",
  // 自定义 agent
  custom: "./bin/my-acp-server"
};
```

**OrchAI 应用**：
- 在 `config/agents.yaml` 中定义 agent 命令
- 支持项目级覆盖（`.acpxrc.json`）
- 支持自定义 agent 路径

### 1.3 Session 管理机制（✅ 采用）

**Session 路由逻辑**：
```
1. 从 cwd 向上遍历到最近的 git root
2. 匹配 (agent command, dir, optional name)
3. -s <name> 选择并行命名会话
4. 无 git root 时仅匹配精确 cwd
```

**持久化结构**：
```typescript
type SessionRecord = {
  sessionId: string;
  agentCommand: string;
  cwd: string;
  acpSessionId: string;
  messages: SessionConversation[];
  lastUsedAt: string;
  createdAt: string;
};
```

**OrchAI 应用**：
- 使用 `~/.orchai/sessions/` 存储会话
- 支持按项目 + agent 类型自动路由
- 支持命名会话实现并行工作流

### 1.4 权限管理（✅ 采用）

```typescript
type PermissionMode = "approve-all" | "approve-reads" | "deny-all";

// 自动批准读操作
isAutoApprovedReadKind(kind) → kind === "read" || kind === "search"
```

**OrchAI 应用**：
- 默认 `approve-reads`（安全）
- 项目级配置覆盖
- 敏感操作（写文件、执行命令）需要确认

### 1.5 队列 IPC 机制（⚠️ 简化使用）

**原理**：通过 Unix socket 实现提示排队和会话控制

**OrchAI 简化方案**：
- 短任务：直接同步执行（无需队列）
- 长任务：通过 Temporal 管理（替代队列 IPC）

---

## 二、Agency Swarm 项目核心借鉴点

### 2.1 MasterContext 模式（✅ 强烈推荐）

```python
@dataclass
class MasterContext:
    thread_manager: ThreadManager
    agents: dict[str, Agent]
    user_context: dict[str, Any]
    agent_runtime_state: dict[str, AgentRuntimeState]
    current_agent_name: str | None
    shared_instructions: str | None
```

**OrchAI 应用**：
```typescript
interface OrchAIContext {
  sessionManager: SessionManager;
  agents: Map<string, AgentConfig>;
  userContext: Record<string, any>;
  agentRuntimeState: Map<string, AgentRuntimeState>;
  currentAgent: string | null;
  sharedInstructions: string | null;
  mcpServers: Map<string, MCPServer>;
}
```

### 2.2 通信流定义（✅ 采用，但需调整）

**Agency Swarm 方式**：
```python
agency = Agency(
    ceo,
    communication_flows=[
        ceo > developer,
        ceo > va,
        developer > va
    ]
)
```

**OrchAI 调整**：
```yaml
# config/communication_flows.yaml
flows:
  - from: router
    to: [code-reviewer, feature-developer, bug-fixer]
  - from: feature-developer
    to: [tester, doc-writer]
  - from: code-reviewer
    to: [security-reviewer]
```

**原因**：
- Agency Swarm 是同步通信（等待响应）
- OrchAI 需要支持异步任务分发
- 使用 YAML 配置更灵活

### 2.3 工具系统设计（✅ 采用）

**两种定义方式**：
```python
# 方式1：BaseTool（Pydantic 模型）
class AddTool(BaseTool):
    a: int = Field(..., ge=0)
    b: int = Field(..., ge=0)

    def run(self) -> str:
        return str(self.a + self.b)

# 方式2：@function_tool（装饰器）
@function_tool
def add_numbers(a: int, b: int) -> str:
    return str(a + b)
```

**OrchAI 应用**：
- 支持 MCP 工具（标准化）
- 支持项目级 Skills（Claude Code/OpenCode）
- 支持自定义工具（Python/TypeScript）

### 2.4 持久化钩子（✅ 采用）

```python
class PersistenceHooks:
    def on_run_start(self, *, context: MasterContext):
        # 加载消息历史
        pass

    def on_run_end(self, *, context: MasterContext, result: RunResult):
        # 保存消息历史
        pass
```

**OrchAI 应用**：
```typescript
interface PersistenceHooks {
  onSessionStart(sessionId: string): Promise<Message[]>;
  onSessionEnd(sessionId: string, messages: Message[]): Promise<void>;
  onAgentStart(agentId: string, context: OrchAIContext): Promise<void>;
  onAgentEnd(agentId: string, result: AgentResult): Promise<void>;
}
```

### 2.5 文件/工具自动发现（✅ 采用）

**Agency Swarm 方式**：
```python
agent = Agent(
    files_folder="./files",
    tools_folder="./tools"
)
```

**OrchAI 应用**：
- 自动扫描 `.claude/skills/` 或 `.opencode/skills/`
- 自动加载项目级 MCP 配置
- 自动发现 git root 和项目结构

---

## 三、不适用的部分

### 3.1 acpx 不适用部分

| 部分 | 原因 |
|------|------|
| 队列 IPC 服务器 | OrchAI 使用 Temporal 管理长任务 |
| TTL 和优雅关闭 | 短任务直接执行，长任务由 Temporal 管理 |
| 复杂的权限提示 | 简化为三级：approve-all/approve-reads/deny-all |

### 3.2 Agency Swarm 不适用部分

| 部分 | 原因 |
|------|------|
| OpenAI Agents SDK 依赖 | OrchAI 需要多模型支持（Claude、Gemini 等） |
| 同步通信限制 | OrchAI 需要异步任务分发 |
| 文件上传到 OpenAI | OrchAI 使用本地文件管理 |
| 内置 UI | OrchAI 使用 OpenClaw UI |

---

## 四、核心设计模式总结

### 4.1 从 acpx 借鉴

```
┌─────────────────────────────────────────────────────────┐
│ 1. ACP 协议（JSON-RPC 2.0 over stdio）                  │
│    → 标准化 agent 通信                                   │
│                                                         │
│ 2. Session 管理（按 git root 作用域）                   │
│    → 自动路由到正确的项目                                │
│                                                         │
│ 3. Agent 注册表（命令映射）                              │
│    → 支持多种 CLI agent                                  │
│                                                         │
│ 4. 权限管理（approve-all/approve-reads/deny-all）       │
│    → 安全的文件系统访问                                  │
└─────────────────────────────────────────────────────────┘
```

### 4.2 从 Agency Swarm 借鉴

```
┌─────────────────────────────────────────────────────────┐
│ 1. MasterContext 模式                                   │
│    → 集中管理共享状态                                    │
│                                                         │
│ 2. 通信流定义（声明式）                                  │
│    → 显式定义允许的通信路径                              │
│                                                         │
│ 3. 工具系统（BaseTool + @function_tool）                │
│    → 灵活的工具定义方式                                  │
│                                                         │
│ 4. 持久化钩子（生命周期管理）                            │
│    → 解耦存储实现                                        │
│                                                         │
│ 5. 文件/工具自动发现                                     │
│    → 减少样板代码                                        │
└─────────────────────────────────────────────────────────┘
```

---

## 五、关键文件参考

### acpx 关键文件
- `/home/wufei/github.com/openclaw/acpx/src/client.ts` - ACP 客户端
- `/home/wufei/github.com/openclaw/acpx/src/agent-registry.ts` - Agent 注册表
- `/home/wufei/github.com/openclaw/acpx/src/session-runtime/lifecycle.ts` - Session 生命周期
- `/home/wufei/github.com/openclaw/acpx/src/permissions.ts` - 权限管理
- `/home/wufei/github.com/openclaw/acpx/src/filesystem.ts` - 文件系统处理

### Agency Swarm 关键文件
- `/home/wufei/github.com/VRSEN/agency-swarm/src/agency_swarm/agency/core.py` - Agency 编排器
- `/home/wufei/github.com/VRSEN/agency-swarm/src/agency_swarm/agent/core.py` - Agent 定义
- `/home/wufei/github.com/VRSEN/agency-swarm/src/agency_swarm/context.py` - MasterContext
- `/home/wufei/github.com/VRSEN/agency-swarm/src/agency_swarm/tools/base_tool.py` - 工具系统
- `/home/wufei/github.com/VRSEN/agency-swarm/src/agency_swarm/hooks.py` - 持久化钩子
