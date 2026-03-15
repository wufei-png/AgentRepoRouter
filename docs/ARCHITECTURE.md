# 系统架构

## 架构分层

### 1. 交互控制层
**OpenClaw**
- 统一入口和 Web UI
- Session 管理
- Workspace 路由
- 记忆持久化（Markdown）

### 2. 编排层
**直连模式** (默认，< 30 分钟任务)
```
OpenClaw → Router → ACP → Agent
```

**耐久模式** (可选，> 30 分钟任务)
```
OpenClaw → Temporal Workflow → Activities → ACP → Agent
```

### 3. Agent 执行层
通过 ACP 协议接入：
- Claude Code
- Codex CLI
- OpenCode
- Cursor

### 4. 工具/知识层
通过 MCP 协议接入：
- GitHub/GitLab (认证、PR、Issue)
- 文档检索
- 知识库搜索
- 本地文件系统 (STDIO)

## 核心组件

### Router Skill
- LLM 驱动的任务分类器
- 输入：用户任务描述
- 输出：任务类型 + 目标 Repo + 推荐 Agent

任务类型：
- `code_review` - 代码审查
- `knowledge_qa` - 知识库问答
- `feature_impl` - 特性实现
- `bugfix` - Bug 修复
- `infra` - 基础设施任务

### ACP 调度流程
```python
1. Router 判断任务 → 选择 Repo
2. 切换到 Repo 目录
3. ACP 启动 Agent (带 --project 或 cd)
4. Agent 自动加载该 Repo 的 project-level skills
5. 执行任务
6. 进程结束，返回结果
```

### MCP 配置策略

**共享型 MCP** (统一 Gateway)
- github
- gitlab
- docs/context7
- knowledge-search

**本地型 MCP** (STDIO，按需配置)
- filesystem
- shell
- git-local
- browser

## 技术决策

### 为什么选 OpenClaw？
- 内置 ACP 支持，可直接管理多个 coding CLI
- Workspace 和 session 管理开箱即用
- 浏览器控制台
- 三级 Skills 体系（内置/本地/工作区）

### 为什么 Temporal 可选？
- 短任务直连更快
- 长任务才需要耐久性、重试、恢复
- 避免过度设计

### 为什么不用 LangGraph？
- LangGraph 适合固定流程
- 我们需要动态 agent 调度
- 不适合"今天接 Codex，明天换 Cursor"的灵活性

## 数据流

### 短任务流程
```
用户输入
→ OpenClaw Gateway
→ Router Skill (LLM 判断)
→ 选择 Repo + Agent
→ ACP 启动 Agent (在 Repo 目录)
→ Agent 执行 (加载 project skills)
→ 结果返回 OpenClaw
→ 展示给用户
```

### 长任务流程
```
用户输入
→ OpenClaw Gateway
→ 创建 Temporal Workflow
→ Workflow 拆分 Activities
→ 并发调度多个 Agent
→ 汇总结果
→ 持久化状态
→ 返回 OpenClaw
```

## 目录结构

```
OrchAI/
├── config/
│   ├── openclaw.yaml       # OpenClaw 配置
│   ├── agents/             # Agent 定义
│   ├── projects.yaml       # 项目 → Agent 映射
│   └── mcp.yaml            # MCP 配置
├── skills/
│   └── router/             # Router Skill
├── workflows/              # Temporal workflows (可选)
└── repos/                  # 管理的项目
    ├── project-a/
    │   └── .claude/skills/ # 项目级 skills
    └── project-b/
        └── .opencode/skills/
```
