# AgentRepoRouter 迁移决策

## 最终架构

```
install.sh → OpenClaw Skill (运行时)
```

两层各司其职：
- **install.sh** — 检查环境、收集 CLI/Repo 选择、部署 Skill 和配置
- **OpenClaw Skill** — 运行时路由和执行

---

## 关键决策

### 1. CLI 调用方式：直接 CLI

**不用 acpx**，直接调用各 CLI：

| Agent | 命令格式 |
|-------|---------|
| Claude Code | `claude "task"` / `claude -p "task"` |
| OpenCode | `opencode run "task"` |
| Cursor | `agent -p "task"` |
| Codex | `codex exec "task"` |

**原因**：
- acpx 不支持 Cursor
- 直接 CLI 更贴近各工具的原生命令和提示词约定
- 更直接，无额外抽象层

### 2. Fallback 机制

用户勾选需要的 CLI，**顺序写入 repo_mappings.json**：

```json
{
  "executionClis": ["claude-code", "opencode", "cursor", "codex", "hermes"]
}
```

运行时按 executionClis 顺序尝试，可用则用，不可用则 fallback 到下一个。

### 3. 路由方式：LLM 判断

**不是关键词匹配**，而是在 Skill.md 中描述任务类型分类和 Agent 选择逻辑，让 LLM 自行判断。

Skill.md 读取 `repo_mappings.json` 了解项目列表，根据任务内容决定：
- 用哪个 Agent
- 在哪个项目执行
- 是否优先考虑 repo 中已检测到的 project-level skill
- 是否优先考虑 repo 中已检测到的 project-level agent

### 4. Skill.md 职责

OpenClaw Skill (`router/SKILL.md`) 负责：
- 读取 `repo_mappings.json`
- 列出可用项目和 Agents
- LLM 判断任务类型
- 选择合适的 Agent + 项目
- 执行命令并处理 fallback

### 5. 项目发现方式

**两种模式**：
1. **Auto scan**：指定根目录，扫描所有含 `.git` 的子目录
2. **Manual**：用户输入项目绝对路径列表

---

## install.sh 流程

```
1. 检查环境（Node.js 18+, Git, OpenClaw）
2. 用户勾选需要的 CLI（claude-code, opencode, cursor, codex）
3. 选择项目发现模式：
   - Auto scan: 输入根目录路径
   - Manual: 输入项目路径列表
4. 生成 `~/.openclaw/skills/agent-repo-router/references/repo_mappings.json`
5. 部署 router/SKILL.md 到 ~/.openclaw/skills/
```

---

## 文件结构

```
~/.openclaw/skills/
└── router/
    ├── SKILL.md                     # 路由逻辑
    └── references/
        └── repo_mappings.json       # 项目和 Agent 配置
```

---

## repo_mappings.json 结构

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

---

## 为什么废弃 Python

| 旧 Python | 新方案 |
|-----------|--------|
| router.py | OpenClaw Skill |
| acp_adapter.py | 直接 CLI |
| validator.py | Skill 内处理 |
| config.py | repo_mappings.json |
| cli.py/init.py | install.sh |

**结果**：旧的 Python runtime 被 Shell installer + Skill Markdown 替代

---

## 保留内容

| 内容 | 去向 |
|------|------|
| Skills 定义 | 迁移到 `~/.openclaw/skills/` |
| repo_mappings.json | 保留，作为配置格式 |
| 现有的测试 repos | 保留，作为参考 |

---

## 下一步

详见 [plan.md](./plan.md)
