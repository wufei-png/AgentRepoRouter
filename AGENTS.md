# AgentRepoRouter - Repo-Aware Router for AI Coding CLIs

## 项目简介

AgentRepoRouter 是一个本地运行的 AI 编程助理路由 skill，可安装到 OpenClaw、Claude Code、OpenCode、Codex 与 Hermes。它根据任务选择合适的 repo、project skill、project agent 与执行 CLI，并保持各 CLI 的原生命令和目录约定。

## 核心能力

- **多 host 安装**: 支持全局安装并软链接到多个 host，也支持单 host 直接安装。
- **智能路由**: LLM 根据 repo metadata、aliases、project skills、project agents 判断执行路径。
- **直接 CLI**: 直接调用各 Agent CLI，无中间协议。
- **多语言支持**: Skill 支持中文/英文。

## 技术栈

- **运行层**: Agent skill host（OpenClaw / Claude Code / OpenCode / Codex / Hermes）
- **Agent 层**: Claude Code / OpenCode / Cursor / Codex / Hermes
- **初始化**: Shell 脚本
- **语言**: Shell + Markdown

## 安装语义

默认流程使用 `Global (recommended)`：

1. 写入规范全局目录：`~/.agents/skills/agent-repo-router`
2. 将检测到的 host skill 目录软链接到该目录
3. 生成 schema v2 `references/repo_mappings.json`

安装模式：

| 模式 | 行为 |
|------|------|
| Global | 写入 `~/.agents/skills/agent-repo-router`，并软链接所有检测到的 host |
| Single host | 直接写入单个 host 的 skill 目录；Codex 目标本身就是全局目录 |
| Custom hosts | 写入全局目录，并软链接选中的多个 host |

直接安装路径：

| Host | 路径 |
|------|------|
| OpenClaw | `~/.openclaw/skills/agent-repo-router` |
| Claude Code | `~/.claude/skills/agent-repo-router` |
| OpenCode | `~/.config/opencode/skills/agent-repo-router` |
| Codex | `~/.agents/skills/agent-repo-router` |
| Hermes | `~/.hermes/skills/software-development/agent-repo-router` |

## 核心组件

### install.sh

安装脚本，负责初始化配置：

```bash
curl -fsSL https://raw.githubusercontent.com/wufei-png/AgentRepoRouter/main/scripts/install.sh | bash
```

流程：

1. 检查环境（Node.js, Git）并检测可用 host
2. 选择语言（中文/English）
3. 选择安装模式（Global / Single host / Custom hosts）
4. 选择安装 host
5. 选择执行 CLI
6. 发现项目（Auto scan / Manual）
7. 将选中语言模板部署为目标目录的 `SKILL.md`
8. 写入 `references/repo_mappings.json`

### skills/agent-repo-router/

Router Skill 源文件：

```text
skills/agent-repo-router/
├── SKILL.zh.md
├── SKILL.en.md
└── references/
    ├── guide.zh.md
    ├── guide.en.md
    └── repo_mappings.json
```

### repo_mappings.json

```json
{
  "schemaVersion": 2,
  "installMode": "global",
  "installHosts": ["global", "openclaw", "claude-code", "opencode", "codex", "hermes"],
  "executionClis": ["claude-code", "opencode", "cursor", "codex", "hermes"],
  "repos": [
    {
      "name": "my-backend",
      "path": "/path/to/backend",
      "aliases": ["backend", "api"],
      "skills": {},
      "agents": {}
    }
  ]
}
```

## CLI 命令格式

| Agent | 命令 | 工作目录 |
|-------|------|---------|
| Claude Code | `claude -p "task"` | `cd /path && claude -p "task"` |
| Claude Code (sub-agent) | `claude --agent <name> "task"` | `cd /path && claude --agent <name> "task"` |
| OpenCode | `opencode run "task"` | `cd /path && opencode run "task"` |
| Cursor | `agent -p "task"` | `cd /path && agent -p "task"` |
| Codex | `codex exec "task"` | `cd /path && codex exec "task"` |
| Hermes | `hermes --oneshot "task"` | `cd /path && hermes --oneshot "task"` |

Codex 官方 CLI 也支持 `codex exec -C /path/to/repo "task"`；这里仍统一写成 `cd /path && ...`，便于和其他 CLI 对齐。

## Agent 和 Skill 调用规范

### 自定义 Agent

| 工具 | 全局路径 | 项目路径 | 调用方式 |
|------|---------|---------|---------|
| Claude Code | `~/.claude/agents/` | `<repo>/.claude/agents/` | `--agent <name>` |
| OpenCode | `~/.config/opencode/agents/` | `<repo>/.opencode/agents/` | 提示词 `use agent xxx` |
| Cursor | `~/.cursor/agents/` | `<repo>/.cursor/agents/` | 提示词 `use agent xxx` |

### Codex 自定义 Agent / Skill

- 全局配置：`~/.codex/config.toml`
- 项目级配置：`<repo>/.codex/config.toml`
- 全局自定义 agent：`~/.codex/agents/*.toml`
- 项目级自定义 agent：`<repo>/.codex/agents/*.toml`
- 全局 skill：`$HOME/.agents/skills/`
- 项目级 skill：`<repo>/.agents/skills/`
- 全局说明文件：`~/.codex/AGENTS.md`
- 项目说明文件：`AGENTS.md`

### Skill 调用

```text
use skill agent-repo-router to solve the following task: <task>
```

## 文档导航

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) - 系统架构
- [docs/PRODUCT.md](docs/PRODUCT.md) - 未来规划
- [docs/plans/migration/plan.md](docs/plans/migration/plan.md) - 迁移计划
- [legacy/README.md](legacy/README.md) - 历史归档
