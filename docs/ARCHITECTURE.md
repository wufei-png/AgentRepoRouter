# 系统架构

## 架构分层

### 1. 交互控制层
**Agent Host**
- OpenClaw / Claude Code / OpenCode / Codex / Hermes
- 统一入口和会话管理
- Skill 加载和执行
- Repo 路由

### 2. 路由层
**Router Skill**
- LLM 驱动的任务分类器
- 输入：用户任务描述
- 输出：任务类型 + 目标 Repo + 推荐 Agent

### 3. Agent 执行层
直接 CLI 调用：
- Claude Code
- OpenCode
- Cursor
- Codex
- Hermes

### 4. 工具层
通过各 Agent 内置能力：
- Git 操作
- 文件编辑
- 终端命令
- 浏览器自动化

## 核心组件

### install.sh
安装脚本，负责初始化配置：
1. 检查环境（Node.js, Git）并检测可用 host
2. 选择语言（中文/English）
3. 选择安装模式（Global / Single host / Custom hosts）
4. 选择安装 host
5. 选择执行 CLI 工具
6. 发现项目（Auto scan / Manual）
7. 生成 schema v2 `repo_mappings.json`
8. 部署选中的 Router Skill

### Router Skill
- 读取 `references/repo_mappings.json` 获取配置
- 利用 repo 的 `aliases`、已检测的 `skills` 摘要、已检测的 `agents` 摘要辅助判断
- LLM 判断任务类型
- 选择合适的 Agent
- 执行 CLI 命令

### repo_mappings.json
默认运行时位置：`~/.agents/skills/agent-repo-router/references/repo_mappings.json`

多 host 安装时，各 host 的 skill 目录会软链接到 `~/.agents/skills/agent-repo-router`。单 host 安装时，配置直接写入该 host 的 skill 目录。

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
      "skills": {
        "claude-code": [
          {
            "name": "build_and_test",
            "description": "Run build and tests before finishing changes."
          }
        ]
      },
      "agents": {
        "claude-code": [
          {
            "name": "bugfix",
            "description": "Fix bugs and regressions with targeted changes."
          }
        ]
      }
    }
  ]
}
```

## 技术决策

### 为什么不用 acpx？
- acpx 不支持 Cursor
- 直接 CLI 更好地支持原生命令和提示词约定
- 更直接，无额外抽象层

### 为什么用 Shell 而非 Python？
- 减少依赖
- 安装更简单
- 运行时零开销

### 为什么 LLM 判断而非关键词？
- 更智能的任务分类
- 更好的上下文理解
- 更灵活的配置

## CLI 命令格式

> ⚠️ 统一使用 `cd` 切换工作目录，不用 `--cwd`

| Agent | 命令 | 工作目录切换 |
|-------|------|-------------|
| Claude Code | `claude -p "task"` | `cd /path && claude -p "task"` |
| Claude Code (sub-agent) | `claude --agent <name> "task"` | `cd /path && claude --agent <name> "task"` |
| OpenCode | `opencode run "task"` | `cd /path && opencode run "task"` |
| Cursor | `agent -p "task"` | `cd /path && agent -p "task"` |
| Codex | `codex exec "task"` | `cd /path && codex exec "task"` |
| Hermes | `hermes --oneshot "task"` | `cd /path && hermes --oneshot "task"` |

> Codex 官方 CLI 额外支持 `codex exec -C /path/to/repo "task"`；AgentRepoRouter 文档仍统一使用 `cd /path && ...` 表达运行时模式。

## Agent 和 Skill 调用规范

### 自定义 Agent 路径

| 工具 | 全局路径 | 项目路径 | 调用方式 |
|------|---------|---------|---------|
| Claude Code | `~/.claude/agents/` | `<repo>/.claude/agents/` | `--agent <name>` |
| OpenCode | `~/.config/opencode/agents/` | `<repo>/.opencode/agents/` | 提示词 `use agent xxx` |
| Cursor | `~/.cursor/agents/` | `<repo>/.cursor/agents/` | 提示词 `use agent xxx` |

### AgentRepoRouter 安装路径

| Host | 直接安装路径 |
|------|-------------|
| OpenClaw | `~/.openclaw/skills/agent-repo-router` |
| Claude Code | `~/.claude/skills/agent-repo-router` |
| OpenCode | `~/.config/opencode/skills/agent-repo-router` |
| Codex | `~/.agents/skills/agent-repo-router` |
| Hermes | `~/.hermes/skills/software-development/agent-repo-router` |

### Codex 自定义 Agent / Skill

- 全局配置：`~/.codex/config.toml`
- 项目级配置：`<repo>/.codex/config.toml`
- 全局自定义 agent：`~/.codex/agents/*.toml`
- 项目级自定义 agent：`<repo>/.codex/agents/*.toml`
- 全局 skill：`$HOME/.agents/skills/`
- 项目级 skill：`<repo>/.agents/skills/`
- 全局说明文件：`~/.codex/AGENTS.md`
- 项目说明文件：`AGENTS.md`
- 也可以通过 `config.toml` 里的 `skills.config` 指向 `SKILL.md` 所在目录
- 当前官方约定不是 `.codex/skills/`

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

## 目录结构

```
AgentRepoRouter/
├── scripts/
│   └── install.sh              # 安装脚本
├── skills/
│   └── agent-repo-router/
│       ├── SKILL.zh.md         # Router Skill (中文)
│       ├── SKILL.en.md         # Router Skill (英文)
│       └── references/
│           └── repo_mappings.json
├── tests/repos/               # 测试仓库
│   ├── test-backend/           # Claude Code 项目
│   │   ├── .claude/skills/
│   │   └── .claude/agents/
│   ├── test-docs/             # OpenCode 项目
│   │   ├── .opencode/skills/
│   │   └── .opencode/agents/
│   └── test-subagents/         # 自定义 Agent 测试
│       ├── .claude/agents/
│       ├── .cursor/agents/
│       └── .opencode/agents/
└── legacy/                     # 历史归档
```

## 迁移历程

详见 [docs/plans/migration/plan.md](docs/plans/migration/plan.md)

### 旧架构 (Python + acpx)
```
install.sh → init → Python Runtime → acpx → Agent
```

### 新架构 (Shell + Skill)
```
install.sh → OpenClaw Skill (LLM 路由) → 直接 CLI → Agent
```
