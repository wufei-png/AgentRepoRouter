# OrchAI 完善实现方案与可行性分析

## 一、核心架构设计（基于参考项目优化）

### 1.1 整体架构

```
┌─────────────────────────────────────────────────────────────┐
│                    OpenClaw (UI 层)                          │
│  - Web UI / TUI                                             │
│  - Session 可视化                                            │
│  - 用户交互                                                  │
└──────────────────┬──────────────────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────────────────┐
│              OrchAI Core (编排层)                            │
│  ┌────────────────────────────────────────────────────┐    │
│  │ MasterContext (借鉴 Agency Swarm)                  │    │
│  │  - SessionManager                                  │    │
│  │  - AgentRegistry                                   │    │
│  │  - UserContext (共享状态)                          │    │
│  │  - RuntimeState                                    │    │
│  └────────────────────────────────────────────────────┘    │
│                                                             │
│  ┌────────────────────────────────────────────────────┐    │
│  │ Router (LLM 驱动)                                  │    │
│  │  - 任务分类                                        │    │
│  │  - 项目匹配                                        │    │
│  │  - Agent 选择                                      │    │
│  └────────────────────────────────────────────────────┘    │
│                                                             │
│  ┌────────────────────────────────────────────────────┐    │
│  │ TaskDispatcher                                     │    │
│  │  - 短任务 → 直接执行                               │    │
│  │  - 长任务 → Temporal Workflow                      │    │
│  └────────────────────────────────────────────────────┘    │
└──────────────────┬──────────────────────────────────────────┘
                   │
        ┌──────────┴──────────┐
        │                     │
┌───────▼────────┐   ┌────────▼─────────┐
│  ACP 适配层     │   │ Temporal Worker  │
│ (借鉴 acpx)    │   │                  │
└───────┬────────┘   └────────┬─────────┘
        │                     │
┌───────▼─────────────────────▼─────────┐
│         Agent 执行层                   │
│  - Claude Code                        │
│  - OpenCode                           │
│  - Codex                              │
│  - Cursor                             │
└───────────────────────────────────────┘
```

### 1.2 核心组件

#### A. MasterContext（中央状态管理）

```typescript
interface OrchAIContext {
  // Session 管理
  sessionManager: SessionManager;

  // Agent 注册表
  agents: Map<string, AgentConfig>;

  // 用户上下文（跨会话共享）
  userContext: {
    preferences: UserPreferences;
    memory: ConversationMemory;
    workspaces: WorkspaceConfig[];
  };

  // Agent 运行时状态
  agentRuntimeState: Map<string, {
    status: 'idle' | 'running' | 'paused';
    currentTask: string | null;
    lastActive: Date;
  }>;

  // 当前活跃 Agent
  currentAgent: string | null;

  // 共享指令
  sharedInstructions: string | null;

  // MCP 服务器（统一共享）
  mcpServers: Map<string, MCPServerConfig>;
}
```

#### B. SessionManager（借鉴 acpx）

```typescript
interface SessionRecord {
  sessionId: string;
  agentCommand: string;
  cwd: string;              // 工作目录
  gitRoot: string | null;   // Git 根目录
  acpSessionId: string;
  messages: Message[];
  metadata: {
    projectName: string;
    taskType: string;
    createdAt: Date;
    lastUsedAt: Date;
  };
}

class SessionManager {
  // 按 (git root, agent, name) 路由
  findOrCreateSession(cwd: string, agent: string, name?: string): SessionRecord;

  // 持久化到 ~/.orchai/sessions/
  saveSession(session: SessionRecord): Promise<void>;
  loadSession(sessionId: string): Promise<SessionRecord>;

  // 并行会话支持
  listActiveSessions(gitRoot: string): SessionRecord[];
}
```

#### C. Router（LLM 驱动的任务路由）

```typescript
interface RouterInput {
  userTask: string;
  context: {
    currentDir: string;
    recentFiles: string[];
    gitStatus: string;
  };
}

interface RouterOutput {
  taskType: 'code-review' | 'feature' | 'bugfix' | 'qa' | 'infra';
  targetRepo: string;
  targetAgent: string;
  estimatedDuration: number; // 分钟
  requiresLongRunning: boolean;
  keywords: string[];
}

class Router {
  async route(input: RouterInput): Promise<RouterOutput> {
    // 使用 LLM 分析任务
    const analysis = await this.llm.analyze(input);

    // 匹配项目
    const repo = this.matchRepository(analysis.keywords, input.context);

    // 选择 Agent
    const agent = this.selectAgent(repo, analysis.taskType);

    return {
      taskType: analysis.taskType,
      targetRepo: repo,
      targetAgent: agent,
      estimatedDuration: analysis.estimatedDuration,
      requiresLongRunning: analysis.estimatedDuration > 30,
      keywords: analysis.keywords
    };
  }
}
```

#### D. ACP 适配层（直接使用 acpx）

```typescript
import { AcpClient } from 'acpx';

class ACPAdapter {
  private clients: Map<string, AcpClient> = new Map();

  async executeTask(
    agent: string,
    cwd: string,
    task: string,
    sessionName?: string
  ): Promise<AgentResult> {
    // 获取或创建 ACP 客户端
    const client = await this.getOrCreateClient(agent, cwd);

    // 创建或恢复会话
    const session = await client.createSession();

    // 提交任务
    await client.submitPrompt(session.id, { text: task });

    // 等待结果
    return this.waitForResult(client, session.id);
  }

  private async getOrCreateClient(agent: string, cwd: string): Promise<AcpClient> {
    const key = `${agent}:${cwd}`;
    if (!this.clients.has(key)) {
      const command = AGENT_REGISTRY[agent];
      const client = new AcpClient({
        command,
        cwd,
        permissions: 'approve-reads'
      });
      await client.initialize();
      this.clients.set(key, client);
    }
    return this.clients.get(key)!;
  }
}
```

---

## 二、实现阶段规划

### Phase 1: MVP（2-3 周）

**目标**：基础任务路由 + 单 Agent 执行

```
用户任务 → Router → 找到项目 → ACP 启动 Agent → 返回结果
```

**核心功能**：
- [x] 安装 OpenClaw
- [ ] 实现 MasterContext
- [ ] 实现 SessionManager（基于 acpx）
- [ ] 实现 Router（简单规则 + LLM）
- [ ] 集成 ACP 适配层
- [ ] 配置 3-5 个测试项目

**技术栈**：
- TypeScript
- acpx（ACP 客户端）
- OpenClaw（UI）
- SQLite（Session 持久化）

**验收标准**：
- 能够识别用户任务类型
- 能够路由到正确的项目目录
- 能够启动对应的 Agent 执行任务
- 能够返回执行结果

### Phase 2: 多 Agent 协作（3-4 周）

**目标**：支持任务分解 + 多 Agent 并行

```
复杂任务 → Router 分解 → 多个子任务 → 并行执行 → 结果聚合
```

**核心功能**：
- [ ] 实现通信流定义（借鉴 Agency Swarm）
- [ ] 实现任务分解器
- [ ] 实现结果聚合器
- [ ] 支持 Agent 间消息传递
- [ ] 实现持久化钩子

**示例场景**：
```
用户：实现用户登录功能

Router 分解：
1. feature-developer: 实现登录 API
2. tester: 编写测试用例
3. security-reviewer: 安全审查
4. doc-writer: 更新文档

并行执行 → 结果聚合 → 返回给用户
```

### Phase 3: Temporal 集成（2-3 周）

**目标**：支持长任务 + 定时任务

```
长任务 → Temporal Workflow → Activities → 状态持久化 → 可恢复
```

**核心功能**：
- [ ] 实现 Temporal Workflow
- [ ] 实现 Activities（调用 ACP）
- [ ] 实现任务暂停/恢复
- [ ] 实现定时任务调度
- [ ] 实现进度查询

**示例场景**：
```
用户：重构整个认证模块（预计 2 小时）

→ Temporal Workflow:
  1. 分析现有代码（Activity 1）
  2. 设计新架构（Activity 2）
  3. 逐步重构（Activity 3-10）
  4. 运行测试（Activity 11）
  5. 生成报告（Activity 12）

中途可暂停、恢复、查询进度
```

---

## 三、关键技术决策

### 3.1 为什么选择 acpx？

| 优势 | 说明 |
|------|------|
| ✅ 标准化协议 | JSON-RPC 2.0，避免 PTY 抓取 |
| ✅ 多 Agent 支持 | 内置 10+ Agent 注册表 |
| ✅ Session 管理 | 按 git root 自动路由 |
| ✅ 权限控制 | 三级权限模式 |
| ✅ 生产就绪 | OpenClaw 官方使用 |

### 3.2 为什么借鉴 Agency Swarm？

| 优势 | 说明 |
|------|------|
| ✅ MasterContext 模式 | 集中管理共享状态 |
| ✅ 通信流定义 | 声明式、易维护 |
| ✅ 工具系统 | 灵活的工具定义 |
| ✅ 持久化钩子 | 解耦存储实现 |
| ⚠️ 需要调整 | 去除 OpenAI 依赖 |

### 3.3 为什么使用 Temporal？

| 优势 | 说明 |
|------|------|
| ✅ 耐久性 | 任务状态持久化 |
| ✅ 可恢复 | 中断后可继续 |
| ✅ 可观测 | 进度查询、审计轨迹 |
| ✅ 可扩展 | 支持分布式 Worker |
| ⚠️ 复杂度 | 仅用于长任务（>30min） |

---

## 四、可行性分析

### 4.1 技术可行性：✅ 高

| 组件 | 可行性 | 依据 |
|------|--------|------|
| ACP 适配 | ✅ 高 | acpx 已生产验证 |
| Session 管理 | ✅ 高 | 直接使用 acpx 实现 |
| Router | ✅ 高 | LLM 分类任务成熟 |
| 多 Agent 协作 | ⚠️ 中 | 需要自研通信层 |
| Temporal 集成 | ✅ 高 | 官方 SDK 完善 |

### 4.2 工程复杂度：⚠️ 中等

**简单部分**：
- ACP 适配（直接用 acpx）
- Session 管理（直接用 acpx）
- Router（LLM + 规则）

**复杂部分**：
- 多 Agent 通信协议
- 任务分解和聚合
- Temporal Workflow 设计

**建议**：
- MVP 阶段避开复杂部分
- 先做单 Agent 路由
- 逐步迭代多 Agent 协作

### 4.3 性能可行性：✅ 高

**短任务（<30min）**：
- 直接 ACP 调用，延迟 <1s
- Session 复用，无冷启动

**长任务（>30min）**：
- Temporal 异步执行
- 不阻塞用户交互

**并行任务**：
- 多 Agent 并行执行
- 受限于 API 配额

### 4.4 成本可行性：✅ 高

**开发成本**：
- MVP: 2-3 周（1 人）
- 完整版: 8-10 周（1-2 人）

**运行成本**：
- 本地运行，无服务器成本
- API 成本取决于使用量
- Temporal 可本地部署（免费）

---

## 五、风险与缓解

### 5.1 技术风险

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| ACP 协议变更 | 高 | 使用稳定版本，监控更新 |
| Agent 不兼容 | 中 | 提供 fallback 机制 |
| Session 冲突 | 中 | 使用命名会话隔离 |
| Temporal 复杂度 | 低 | 仅用于长任务 |

### 5.2 工程风险

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| 过度设计 | 高 | MVP 优先，逐步迭代 |
| 多 Agent 通信复杂 | 中 | Phase 2 再实现 |
| 测试覆盖不足 | 中 | 每个 Phase 写测试 |

---

## 六、下一步行动

### 立即开始（本周）

1. **搭建项目结构**
   ```bash
   mkdir -p orchai/{core,adapters,router,config}
   ```

2. **安装依赖**
   ```bash
   npm install acpx
   npm install @temporalio/client @temporalio/worker
   ```

3. **实现 MasterContext**
   - 定义 TypeScript 接口
   - 实现基础的状态管理

4. **集成 acpx**
   - 封装 ACP 客户端
   - 测试与 Claude Code 通信

5. **实现简单 Router**
   - 基于关键字匹配
   - 测试任务分类

### 本月目标

- [ ] 完成 MVP Phase 1
- [ ] 能够路由 3-5 个测试项目
- [ ] 能够执行简单任务并返回结果

### 下月目标

- [ ] 开始 Phase 2（多 Agent 协作）
- [ ] 实现任务分解
- [ ] 实现结果聚合
