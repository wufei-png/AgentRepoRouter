# 系统架构

## 架构分层

### 1. 交互控制层
**OpenClaw**
- 统一入口和会话管理
- Skill 加载和执行
- Workspace 路由

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

### 4. 工具层
通过各 Agent 内置能力：
- Git 操作
- 文件编辑
- 终端命令
- 浏览器自动化

## 核心组件

### install.sh
安装脚本，负责初始化配置：
1. 检查环境（Node.js, Git, OpenClaw）
2. 选择语言（中文/English）
3. 选择 CLI 工具
4. 发现项目（Auto scan / Manual）
5. 生成 `~/.openclaw/skills/router/references/repo_mappings.json`
6. 部署选中的 Router Skill 为 `~/.openclaw/skills/router/SKILL.md`

### Router Skill
- 读取 `references/repo_mappings.json` 获取配置
- LLM 判断任务类型
- 选择合适的 Agent
- 执行 CLI 命令

### repo_mappings.json
运行时位置：`~/.openclaw/skills/router/references/repo_mappings.json`

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

## Agent 和 Skill 调用规范

### 自定义 Agent 路径

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

## 目录结构

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
