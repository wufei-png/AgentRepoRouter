---
name: router
description: "路由编码任务到合适的仓库和 Agent。当用户想要在某个项目上工作或执行编码任务时使用。"
---

# Router Skill

读取 `references/repo_mappings.json` 获取配置。

## CLI 命令格式

> 统一使用 `cd` 切换工作目录

| Agent平台                   | 命令                           | 工作目录切换                               |
| ----------------------- | ------------------------------ | ------------------------------------------ |
| Claude Code             | `claude -p "task"`             | `cd /path && claude -p "task"`             |
| Claude Code (sub-agent) | `claude --agent <name> "task"` | `cd /path && claude --agent <name> "task"` |
| OpenCode                | `opencode run "task"`          | `cd /path && opencode run "task"`          |
| Cursor                  | `agent -p "task"`              | `cd /path && agent -p "task"`              |
| Codex                   | `codex exec "task"`            | `cd /path && codex exec "task"`            |

> **重要**：Cursor 的 CLI 可执行名就是 `agent`，不是 `cursor agent`。由于 `agent` 这个名字比较通用，模型容易误写成 `cursor agent -p`，但这是错误命令；涉及 Cursor CLI 时始终直接使用 `agent -p "task"`。
>
> **补充**：Codex 官方 CLI 也支持 `codex exec -C /path/to/repo "task"`。Router 文档里仍统一使用 `cd /path && ...`，以保持所有 CLI 的调用模式一致。

## Agent 自定义路径

| 工具        | 全局路径                     | 项目路径                   | 原生 CLI 调用       | 提示词调用         |
| ----------- | ---------------------------- | -------------------------- | ------------------- | ------------------ |
| Claude Code | `~/.claude/agents/`          | `<repo>/.claude/agents/`   | ✅ `--agent <name>` | ✅ `use agent xxx` |
| OpenCode    | `~/.config/opencode/agents/` | `<repo>/.opencode/agents/` | ❌                  | ✅ `use agent xxx` |
| Cursor      | `~/.cursor/agents/`          | `<repo>/.cursor/agents/`   | ❌                  | ✅ `use agent xxx` |

> **注意**：Cursor 和 OpenCode 的自定义 agent 只能通过**提示词**调用，不能通过 CLI 参数。

### Codex 自定义 Agent / Skill

- 全局配置：`~/.codex/config.toml`
- 项目级配置：`<repo>/.codex/config.toml`
- 全局自定义 agent：`~/.codex/agents/*.toml`
- 项目级自定义 agent：`<repo>/.codex/agents/*.toml`
- 全局 skill：`$HOME/.agents/skills/`
- 项目级 skill：`<repo>/.agents/skills/`
- 全局说明文件：`~/.codex/AGENTS.md`
- 项目说明文件：`AGENTS.md`
- 额外 skill 也可以通过 `config.toml` 中的 `skills.config` 声明路径
- 当前官方约定不是 `.codex/skills/`

## Agent 和 Skill 调用规范

### 自定义 Agent 调用方式

- **Claude Code**: 使用 `--agent <name>` 参数
- **OpenCode / Cursor**: 在提示词中使用 `use agent <name> to do...`

### Skill 调用方式（统一）

```
use skill <skill-name> to solve the following task: <task description>
```

### Agent/Skill 省略规则

| 情况                                        | 提示词写法                 |
| ------------------------------------------- | -------------------------- |
| Agent/Skill 在 agent 文件夹内，且只命中一个 | 省略不提                   |
| Agent/Skill 只命中一个                      | `use skill` 或 `use agent` |
| Agent 和 Skill 都命中                       | 两者都用                   |
| Agent 和 Skill 命令冲突                     | 提示用户，由用户决定       |

### Agent 和 Skill 优先级

按以下顺序决策：

1. **优先使用项目级 Skill 和 Agent**
   - 先检查目标 repo 内的自定义 Skill 和 Agent
   - 例如 `<repo>/.claude/skills/`、`<repo>/.claude/agents/`、`<repo>/.opencode/skills/`、`<repo>/.opencode/agents/`
   - 如果项目级同时命中 Skill 和 Agent，先使用 Skill，再把 Agent 一并带上

2. **项目级未命中时再考虑全局 Skill 和 Agent**
   - 只有项目级没有合适命中时，才考虑对应工具的全局 Skill 和 Agent
   - 全局配置是第二优先级，不能覆盖明确的项目级配置

3. **全局匹配必须更严格**
   - 只有在名称高度一致、任务职责强匹配、或用户明确点名时，才使用全局 Skill / Agent
   - 如果只是弱相关或泛匹配，不要轻易注入全局 Skill / Agent

4. **最后 fallback 到默认**
   - 如果项目级和全局级都没有可信命中，则按 `repo_mappings.json` 中的 agents 顺序 fallback
   - 除非 Skill 命中非常明确，否则不要在 fallback 情况下强行附加 Skill

## 工作流程

### 1. 理解任务

分析用户任务，确定：

- 任务类型（bugfix, feature, refactor, docs, qa, review）
- 目标项目（如未指定，询问用户）
- 匹配到的 Agent 和 Skill

### 2. 选择 Agent 和 Skill

按以下顺序决策：

1. 先匹配项目级 Skill 和 Agent
2. 若项目级未命中，再考虑全局 Skill 和 Agent
3. 全局命中必须比项目级更严格
4. 都未命中时，按 `repo_mappings.json` 中的 agents 顺序 fallback 到默认 Agent

### 3. 执行命令

```bash
# Claude Code
cd /path/to/repo && claude -p "task description"

# Claude Code (sub-agent)
cd /path/to/repo && claude --agent bugfix "task description"

# OpenCode / Cursor（提示词调用 agent）
cd /path/to/repo && opencode run "use agent xxx to do: task description"

# Codex
cd /path/to/repo && codex exec "task description"

# Skill 调用（统一格式）
cd /path/to/repo && opencode run "use skill <skill-name> to solve: task description"
```

### 4. Fallback

如果第一个 Agent 不可用或失败，自动尝试下一个。

### 5. 任务类型分类

| 类型     | 关键词                      |
| -------- | --------------------------- |
| bugfix   | fix, bug, error, issue      |
| feature  | add, implement, create, new |
| refactor | refactor, clean, improve    |
| docs     | doc, readme, guide          |
| qa       | question, how, what, why    |
| review   | review, check, audit        |

### 6. 找不到匹配时的处理

如果用户请求的任务找不到匹配的 agent 或 skill：

1. 使用默认 agent (agents 列表第一个)
2. 执行通用任务

## references/repo_mappings.json

配置文件，定义 agents 顺序和 repos 列表。

```json
{
  "schemaVersion": 1,
  "agents": ["claude-code", "opencode", "cursor", "codex"],
  "repos": [
    {
      "name": "project-name",
      "path": "/path/to/project",
      "type": "backend"
    }
  ]
}
```
