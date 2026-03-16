# OrchAI Config 配置文件说明

本文档详细说明 `config` 目录下所有配置文件的作用、用法、来源和去向。

---

## 文件列表

| 文件 | 作用 |
|------|------|
| `agents.yaml` | 定义系统中可用的 Agent 列表及启用状态 |
| `router_config.yaml` | 配置 Router Agent 的回退策略和行为参数 |
| `mcp.yaml` | 配置 MCP (Model Context Protocol) 服务器 |
| `openclaw.yaml` | 配置 OpenClaw Web 服务器的运行参数 |
| `projects.yaml` | 定义托管的代码仓库列表 |
| `agents/orchai-router.md` | Router Agent 的系统 prompt 定义 |

---

## 1. agents.yaml

### 作用
定义系统中可用的 AI Agent 列表，以及每个 Agent 的启用/禁用状态。OrchAI 通过此配置决定可以使用哪些 Agent 来处理任务。

### 如何使用
编辑 `agents` 列表，添加或修改 agent 条目：
- `name`: Agent 名称
- `enabled`: 是否启用 (true/false)

```yaml
agents:
  - name: orchai-router
    enabled: true
  - name: claude-code
    enabled: true
  - name: opencode
    enabled: true
  - name: codex
    enabled: true
```

### 来源
- **初始化**: 由 `orchai init` 命令自动创建 (参见 `orchai/init.py` 中的 `create_project_config` 函数)
- **模板位置**: 默认模板内嵌在 `init.py` 中

### 去向
- 被 `orchai/config.py` 中的 `Config._load_agents()` 方法加载
- 运行时由 `Config.agents` 属性访问
- 用于判断哪些 agent 可用: `Config.get_enabled_agents()`

---

## 2. router_config.yaml

### 作用
配置 Router Agent 的回退 (fallback) 行为。当 Router 无法确定合适的 repo 或 agent 时使用。

### 如何使用
配置 fallback 策略:
```yaml
fallback:
  enabled: true      # 是否启用回退机制
  max_retries: 3    # 最大重试次数
```

### 来源
- 由 `orchai init` 命令自动创建 (参见 `orchai/init.py` 中的 `create_project_config` 函数)

### 去向
- 被 `orchai/config.py` 中的 `Config._load_router_config()` 方法加载
- 存储在 `Config.router_config` 属性中

---

## 3. mcp.yaml

### 作用
配置 MCP (Model Context Protocol) 服务器列表。MCP 允许 OrchAI 集成外部工具和服务，如 GitHub API、文档检索等。

### 如何使用
添加 MCP 服务器配置:
```yaml
servers:
  - name: github
    command: npx
    args: ["-y", "@modelcontextprotocol/server-github"]
  - name: filesystem
    command: npx
    args: ["-y", "@modelcontextprotocol/server-filesystem", "/path/to/dir"]
```

### 来源
- 由 `orchai init` 命令自动创建 (默认为空配置)
- 用户手动编辑添加 MCP 服务器

### 去向
- 被 `orchai/config.py` 中的 `Config._load_mcp()` 方法加载
- 存储在 `Config.mcp_servers` 属性中
- 供 OpenClaw 启动时初始化 MCP 客户端使用

---

## 4. openclaw.yaml

### 作用
配置 OpenClaw Web 服务器的运行参数，包括服务器地址、工作区目录和 agents 目录位置。

### 如何使用
```yaml
server:
  host: 0.0.0.0   # 监听地址
  port: 3000      # 监听端口

workspace:
  default: ./repos    # 默认工作区目录

agents_dir: ./config/agents   # Agent 定义文件目录
```

### 来源
- 由 `orchai init` 命令自动创建
- 用户可根据需要修改端口、工作区路径等

### 去向
- 被 `orchai/config.py` 中的 `Config._load_openclaw()` 方法加载
- 存储在 `Config.openclaw` 属性中
- OpenClaw 服务启动时读取此配置

---

## 5. projects.yaml

### 作用
定义 OrchAI 管理的代码仓库列表。每个仓库都有一个名称和路径，用于任务路由匹配。

### 如何使用
添加项目仓库:
```yaml
repos:
  - name: test-backend
    path: ./tests/repos/test-backend
  - name: test-docs
    path: ./tests/repos/test-docs
  - name: my-project
    path: /absolute/path/to/project
```

### 来源
- 由 `orchai init` 命令自动创建 (初始为空列表)
- Router Skill 会自动更新此文件 (当用户确认新项目时)

### 去向
- 被 `orchai/config.py` 中的 `Config._load_projects()` 方法加载
- 存储在 `Config.projects` 属性中
- Router Agent 使用 `Config.get_project(name)` 查找项目

---

## 6. agents/orchai-router.md

### 作用
定义 Router Agent 的系统 prompt，即告诉 Router Agent 应该如何工作、承担什么职责。

### 如何使用
这是一个 Markdown 文件，包含 Router Agent 的系统提示词。直接编辑此文件可以修改 Router 的行为逻辑。

主要内容包括:
- Router 的核心职责
- 自我进化机制 (当找不到匹配时)
- 任务类型定义 (feature, bugfix, refactor, docs, qa)
- Agent 选择策略

### 来源
- **模板来源**: `prompts/orchai-router.md`
- **复制时机**: `orchai init` 命令执行时，会从 `prompts/orchai-router.md` 复制到 `config/agents/orchai-router.md`

```python
# init.py 中的逻辑
prompt_path = PROMPTS_DIR / "orchai-router.md"  # prompts/orchai-router.md
target_prompt_path = project_root / "config" / "agents" / "orchai-router.md"
```

### 去向
- 在初始化时，还会复制到用户主目录的 `.openclaw/agents/orchai-router.yaml`
- 被 OpenClaw 加载为 Router Agent 的定义文件

---

## 配置文件加载流程

```
orchai init
    │
    ├── create_project_config() → 生成所有 .yaml 文件
    │
    ├── create_new_agent() 
    │   └── 从 prompts/orchai-router.md → 复制到 config/agents/orchai-router.md
    │   └── 生成 .openclaw/agents/orchai-router.yaml
    │
    └── create_router_skill()
        └── 从 prompts/router-skill.md → 复制到 skills/router/skill.md

运行时:
    Config 类 (config.py)
    │
    ├── _load_openclaw()    → 加载 openclaw.yaml
    ├── _load_agents()      → 加载 agents.yaml
    ├── _load_mcp()         → 加载 mcp.yaml
    ├── _load_projects()   → 加载 projects.yaml
    └── _load_router_config() → 加载 router_config.yaml
```

---

## 常用操作

### 初始化项目配置
```bash
orchai init
```

### 添加新项目
直接编辑 `projects.yaml`:
```bash
vim config/projects.yaml
```

### 启用/禁用 Agent
编辑 `agents.yaml` 中的 `enabled` 字段。

### 修改 Router 行为
编辑 `config/agents/orchai-router.md` 修改系统提示词。

### 配置 MCP 服务器
编辑 `config/mcp.yaml` 添加 MCP 服务器配置。
