# Router Reference

这份参考文档提供 Router Skill 的详细约定。运行时主规则在 `../SKILL.zh.md`。

## CLI 细节

### 通用

- 统一用 `cd /path && ...` 表达运行目录切换。
- 不要写 `--cwd`。
- 只有在主 skill 中没有足够信息时，才回看本参考文档。

### Claude Code

- 基础命令：`claude -p "task"`
- 自定义 agent：`claude --agent <name> "task"`
- 项目级 agent：`<repo>/.claude/agents/`
- 项目级 skill：`<repo>/.claude/skills/`
- 全局 agent：`~/.claude/agents/`

### OpenCode

- 基础命令：`opencode run "task"`
- 自定义 agent 只能通过提示词调用，不能通过 CLI 参数调用。
- 推荐提示词：`use agent <name> to do: <task>`
- 项目级 agent：`<repo>/.opencode/agents/`
- 项目级 skill：`<repo>/.opencode/skills/`
- 全局 agent：`~/.config/opencode/agents/`

### Cursor

- Cursor CLI 可执行名是 `agent`，不是 `cursor agent`。
- 基础命令：`agent -p "task"`
- 自定义 agent 只能通过提示词调用。
- 项目级 agent：`<repo>/.cursor/agents/`
- 全局 agent：`~/.cursor/agents/`

### Codex

- 基础命令：`codex exec "task"`
- 官方也支持 `codex exec -C /path/to/repo "task"`，但 Router 文档统一用 `cd /path && ...`
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

## Router 判断细节

### 项目级优先

- 先看目标 repo 内的自定义 skill / agent。
- 如果 `repo_mappings.json` 的 `skills` 字段已经列出了该 repo 的 project-level skill 摘要，先把这些摘要当作路由强提示。
- 如果项目级同时命中 skill 和 agent，优先保留 skill，再决定是否把 agent 一并带上。

### 全局级保守

- 全局 skill / agent 只在名称高度一致、职责强匹配、或用户明确点名时使用。
- 弱相关时，不要为了“看起来有帮助”就强行注入。

### aliases

- `aliases` 是 repo 的可选别名数组，默认可以为空。
- 如果用户说的是 repo alias 而不是正式目录名，把 alias 视为强 repo 命中信号。

### Fallback

- 都未命中时，按 `repo_mappings.json.agents` 的顺序选择默认 CLI。
- fallback 时默认不要附加弱命中的 skill。

## 常见任务类型

- `bugfix`: 修 bug、修回归、修错误
- `feature`: 新功能、实现需求
- `refactor`: 重构、清理、改进结构
- `docs`: 文档、README、guide
- `qa`: 问答、解释、方案说明
- `review`: 审查、检查、audit
