# OrchAI - AI Coding Agent Orchestrator

## 项目简介

OrchAI 是一个本地运行的 AI 编程助理编排系统，通过 OpenClaw Skill 进行路由，管理多个 coding agent（Claude Code、OpenCode、Cursor），自动路由任务到合适的 agent 和工作目录。

## 核心能力

- **统一入口**: OpenClaw 提供会话管理
- **智能路由**: LLM 判断任务类型并路由
- **工作区隔离**: 每个项目独立工作目录
- **直接 CLI**: 直接调用各 Agent CLI，无中间协议
- **多语言支持**: Skill 支持中文/英文

## 技术栈

- **控制层**: OpenClaw Skill (路由逻辑)
- **Agent 层**: Claude Code / OpenCode / Cursor (直接 CLI)
- **初始化**: Shell 脚本
- **语言**: Shell + Markdown

## 架构概览

```
用户 → OpenClaw
  ↓
Router Skill (LLM 判断路由)
  ↓
选择 Repo + Agent
  ↓
cd 到项目目录 → 直接 CLI 启动 Agent
  ↓
Agent 执行任务
```

## 核心组件

### install.sh

安装脚本，负责初始化配置：

```bash
curl -fsSL https://.../install.sh | bash
```

流程：
1. 检查环境（Node.js, Git, OpenClaw）
2. 选择语言（中文/English）
3. 选择 CLI 工具
4. 发现项目（Auto scan / Manual）
5. 生成 `~/.openclaw/skills/router/references/repo_mappings.json`
6. 部署选中的 Router Skill 为 `~/.openclaw/skills/router/SKILL.md`

### skills/router/

Router Skill 源文件：

```
skills/router/
├── SKILL.zh.md        # 中文版
├── SKILL.en.md        # 英文版
└── references/
    └── repo_mappings.json
```

安装时选择语言，对应文件被部署为 `~/.openclaw/skills/router/SKILL.md`。

### ~/.openclaw/skills/router/references/repo_mappings.json

用户配置文件：

```json
{
  "schemaVersion": 1,
  "agents": ["claude-code", "opencode", "cursor", "codex"],
  "repos": [
    {
      "name": "my-backend",
      "path": "/path/to/backend",
      "type": "backend"
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

## Agent 和 Skill 调用规范

### 自定义 Agent

| 工具 | 全局路径 | 项目路径 | 调用方式 |
|------|---------|---------|---------|
| Claude Code | `~/.claude/agents/` | `<repo>/.claude/agents/` | `--agent <name>` |
| OpenCode | `~/.config/opencode/agents/` | `<repo>/.opencode/agents/` | 提示词 `use agent xxx` |
| Cursor | `~/.cursor/agents/` | `<repo>/.cursor/agents/` | 提示词 `use agent xxx` |

### Skill 调用

```
use skill <skill-name> to solve the following task: <task>
```

### 省略规则

| 情况 | 写法 |
|------|------|
| Agent/Skill 在 agent 文件夹内，且只命中一个 | 省略不提 |
| 只命中一个 | `use skill` 或 `use agent` |
| 两者都命中 | 两者都用 |
| 冲突 | 提示用户选择 |

## 项目结构

```
OrchAI/
├── scripts/
│   └── install.sh              # 安装脚本
├── skills/
│   └── router/
│       ├── SKILL.zh.md         # Router Skill (中文)
│       ├── SKILL.en.md         # Router Skill (英文)
│       └── references/
│           └── repo_mappings.json
├── tests/repos/               # 测试仓库
│   ├── test-backend/           # Claude Code 项目
│   ├── test-docs/              # OpenCode 项目
│   └── test-subagents/         # 自定义 Agent 测试
├── docs/
│   ├── ARCHITECTURE.md
│   ├── PRODUCT.md
│   └── plans/migration/plan.md
└── legacy/                     # 历史归档
```

## 快速开始

```bash
# 安装
curl -fsSL https://.../install.sh | bash

# 或本地安装
bash scripts/install.sh

# 编辑配置
vim ~/.openclaw/skills/router/references/repo_mappings.json

# 启动 OpenClaw
openclaw
```

## 文档导航

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) - 系统架构
- [docs/PRODUCT.md](docs/PRODUCT.md) - 产品愿景
- [docs/plans/migration/plan.md](docs/plans/migration/plan.md) - 迁移计划
- [legacy/README.md](legacy/README.md) - 历史归档
