# AgentRepoRouter 迁移实现计划

> 📅 2026-03-24
> ⚠️ 待 Review - 此计划需用户确认后执行

---

## 概述

将 AgentRepoRouter 从 Python 运行时框架迁移到**纯 Shell 初始化 + OpenClaw Skill 运行时**架构。

```
install.sh → OpenClaw Skill (运行时)
```

### 核心变更

| 项目       | 旧方案     | 新方案             |
| ---------- | ---------- | ------------------ |
| CLI 调用   | acpx       | 直接 CLI           |
| 路由方式   | 关键词匹配 | LLM 判断           |
| 初始化     | Python     | Shell 脚本         |
| Skill 格式 | Python     | OpenClaw Skill     |
| 项目配置   | legacy-python-runtime/    | repo_mappings.json |

---

## 最终设计要点

### CLI 命令格式

> ⚠️ **统一使用 `cd` 切换工作目录**，不用 `--cwd`（各工具均不支持原生 `--cwd`）

| Agent                   | 命令                           | 工作目录切换                               |
| ----------------------- | ------------------------------ | ------------------------------------------ |
| Claude Code             | `claude -p "task"`             | `cd /path && claude -p "task"`             |
| Claude Code (sub-agent) | `claude --agent <name> "task"` | `cd /path && claude --agent <name> "task"` |
| OpenCode                | `opencode run "task"`          | `cd /path && opencode run "task"`          |
| Cursor                  | `agent -p "task"`              | `cd /path && agent -p "task"`              |

### Agent 和 Skill 调用规范

#### 自定义 Agent 调用方式

| 工具        | 原生 Agent CLI | 调用方式                             |
| ----------- | -------------- | ------------------------------------ |
| Claude Code | ✅ 支持        | `claude --agent <name> "task"`       |
| OpenCode    | ❌ 不支持      | 提示词调用：`use agent xxx to do...` |
| Cursor      | ❌ 不支持      | 提示词调用：`use agent xxx to do...` |

**OpenCode/Cursor 提示词格式：**

```
use agent <agent-name> to do the following task: <task description>
```

#### Skill 调用方式（统一）

```
use skill <skill-name> to solve the following task: <task description>
```

#### Agent/Skill 省略规则

| 情况                                        | 提示词写法                 |
| ------------------------------------------- | -------------------------- |
| Agent/Skill 在 agent 文件夹内，且只命中一个 | 省略不提                   |
| Agent/Skill 只命中一个                      | `use skill` 或 `use agent` |
| Agent 和 Skill 都命中                       | 两者都用                   |
| Agent 和 Skill 命令冲突                     | 提示用户，由用户决定       |

#### 命令冲突处理

如果同时匹配 agent 和 skill，且两者指令可能冲突：

1. 先使用 skill
2. 告知用户冲突，询问是否需要切换到 agent

```
⚠️ 检测到 agent 和 skill 可能冲突。
- Agent: <name>
- Skill: <skill-name>
是否继续使用 skill？
```

### Agent 自定义路径（已验证）

| 工具        | 全局路径                     | 项目路径                   | 原生 CLI 调用       | 提示词调用         |
| ----------- | ---------------------------- | -------------------------- | ------------------- | ------------------ |
| Claude Code | `~/.claude/agents/`          | `<repo>/.claude/agents/`   | ✅ `--agent <name>` | ✅ `use agent xxx` |
| OpenCode    | `~/.config/opencode/agents/` | `<repo>/.opencode/agents/` | ❌                  | ✅ `use agent xxx` |
| Cursor      | `~/.cursor/agents/`          | `<repo>/.cursor/agents/`   | ❌                  | ✅ `use agent xxx` |

> **注意**：Cursor 和 OpenCode 的自定义 agent 只能通过**提示词**调用，不能通过 CLI 参数。

### repo_mappings.json 结构

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

## 阶段 1: 重写 install.sh

### 目标

`install.sh` 负责检查环境并初始化配置。

### 流程

```
install.sh
│
├── 1. 检查环境
│   ├── Node.js 18+
│   ├── Git
│   └── OpenClaw 已安装 (否则报错)
│
├── 2. 选择语言（交互式）
│   ├── [1] 中文
│   └── [2] English
│
├── 3. 用户选择执行 CLI（交互式）
│   ├── [ ] claude-code  (检测: command -v claude)
│   ├── [ ] opencode     (检测: command -v opencode)
│   ├── [ ] cursor       (检测: command -v agent)
│   └── [ ] codex        (检测: command -v codex)
│
├── 4. 项目发现
│   ├── 选项 A: Auto scan
│   │   └── 输入根目录 → 扫描 .git 子目录
│   └── 选项 B: Manual
│       └── 输入项目绝对路径
│
├── 5. 生成 ~/.openclaw/skills/agent-repo-router/references/repo_mappings.json
│   └── 包含 installMode、installHosts、executionClis 顺序和 repos 列表
│
└── 6. 部署 Router Skill
    ├── 选择中文 → 复制 SKILL.zh.md 为 SKILL.md，删除 SKILL.en.md
    └── 选择英文 → 复制 SKILL.en.md 为 SKILL.md，删除 SKILL.zh.md
```

### 生成的 repo_mappings.json

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

### CLI 检测映射

| CLI         | 检测命令             | npm 包                    |
| ----------- | -------------------- | ------------------------- |
| claude-code | `claude --version`   | @anthropic-ai/claude-code |
| opencode    | `opencode --version` | opencode-ai               |
| cursor      | `agent --version`    | cursor (官方安装器)       |
| codex       | `codex --version`    | @openai/codex             |

### Edge Cases

| 场景            | 处理               |
| --------------- | ------------------ |
| OpenClaw 未安装 | 报错退出，提示安装 |
| 无效路径        | 验证并提示重新输入 |
| 重复项目名      | 过滤保留一个       |
| 无 sudo 权限    | 提示用户手动安装   |

### 待完成

- [ ] 交互式 CLI 选择
- [ ] Auto scan 逻辑
- [ ] Manual 路径输入
- [ ] 生成 repo_mappings.json
- [ ] 部署 SKILL.md

---

## 阶段 2: 创建 Router SKILL.md

### 目标

OpenClaw Skill 负责运行时路由和执行。

### 文件位置

```
skills/agent-repo-router/
├── SKILL.zh.md        # 中文版
├── SKILL.en.md        # 英文版
└── references/
    └── repo_mappings.json
```

> 安装时根据用户选择，将对应语言的文件 rename 为 `SKILL.md`，删除另一个。

### SKILL.md 内容

```markdown
---
name: router
description: "Route coding tasks to appropriate repos and agents. Use when user wants to work on a project or perform a coding task."
---

# Router Skill

读取 `references/repo_mappings.json` 获取配置。

## CLI 命令格式

> ⚠️ 统一使用 `cd` 切换工作目录，不用 `--cwd`

| Agent                   | 命令                           | 工作目录切换                               |
| ----------------------- | ------------------------------ | ------------------------------------------ |
| Claude Code             | `claude -p "task"`             | `cd /path && claude -p "task"`             |
| Claude Code (sub-agent) | `claude --agent <name> "task"` | `cd /path && claude --agent <name> "task"` |
| OpenCode                | `opencode run "task"`          | `cd /path && opencode run "task"`          |
| Cursor                  | `agent -p "task"`              | `cd /path && agent -p "task"`              |

## Agent 自定义路径

| 工具        | 全局路径                     | 项目路径                   | 原生 CLI 调用       | 提示词调用         |
| ----------- | ---------------------------- | -------------------------- | ------------------- | ------------------ |
| Claude Code | `~/.claude/agents/`          | `<repo>/.claude/agents/`   | ✅ `--agent <name>` | ✅ `use agent xxx` |
| OpenCode    | `~/.config/opencode/agents/` | `<repo>/.opencode/agents/` | ❌                  | ✅ `use agent xxx` |
| Cursor      | `~/.cursor/agents/`          | `<repo>/.cursor/agents/`   | ❌                  | ✅ `use agent xxx` |

## Agent 和 Skill 调用规范

### 自定义 Agent 调用方式

- **Claude Code**: 使用 `--agent <name>` 参数
- **OpenCode / Cursor**: 在提示词中使用 `use agent <name> to do...`

### Skill 调用方式（统一）
```

use skill <skill-name> to solve the following task: <task description>

````

### Agent/Skill 省略规则

| 情况 | 提示词写法 |
|------|-----------|
| Agent/Skill 在 agent 文件夹内，且只命中一个 | 省略不提 |
| Agent/Skill 只命中一个 | `use skill` 或 `use agent` |
| Agent 和 Skill 都命中 | 两者都用 |
| Agent 和 Skill 命令冲突 | 提示用户，由用户决定 |

## 工作流程

### 1. 理解任务

分析用户任务，确定：
- 任务类型（bugfix, feature, refactor, docs, qa, review）
- 目标项目（如未指定，询问用户）
- 匹配到的 Agent 和 Skill

### 2. 选择 Agent

按 repo_mappings.json 中的 executionClis 顺序，选择第一个可用的。

### 3. 执行命令

```bash
# Claude Code
cd /path/to/repo && claude -p "task description"

# Claude Code (sub-agent)
cd /path/to/repo && claude --agent bugfix "task description"

# OpenCode / Cursor（提示词调用 agent）
cd /path/to/repo && opencode run "use agent xxx to do: task description"

# Skill 调用（统一格式）
cd /path/to/repo && opencode run "use skill <skill-name> to solve: task description"
````

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

配置文件，定义 executionClis 顺序和 repos 列表。

```

### 待完成

- [ ] 创建 `skills/agent-repo-router/SKILL.zh.md`
- [ ] 创建 `skills/agent-repo-router/SKILL.en.md`
- [ ] 创建 `skills/agent-repo-router/references/` 目录
- [ ] 维护 `references/repo_mappings.json` 作为唯一配置样板

---

## 阶段 3: 创建测试仓库

### 目标

创建测试仓库以验证所有 CLI 调用和自定义 agent 功能。

### 目录结构

```

tests/repos/
├── test-backend/ # 项目A：用 Claude Code
│ ├── .claude/
│ │ ├── skills/
│ │ │ └── build_and_test/SKILL.md
│ │ └── agents/
│ │ └── bugfix.md
│ └── .git/
│
├── test-docs/ # 项目B：用 OpenCode
│ ├── .opencode/
│ │ ├── skills/
│ │ │ └── doc_writer/SKILL.md
│ │ └── agents/
│ │ └── docs_writer.md
│ └── .git/
│
└── test-subagents/ # 测试自定义 Agents
├── .claude/
│ └── agents/
│ ├── bugfix.md
│ ├── docs.md
│ └── qa.md
├── .cursor/
│ └── agents/
│ └── security.md
├── .opencode/
│ └── agents/
│ └── reviewer.md
└── .git/

````

> **注意**：Cursor 和 OpenCode 的自定义 agent 通过**提示词**调用，不是 CLI 参数。

### 待创建

- [ ] `tests/repos/test-backend/` 及内容
- [ ] `tests/repos/test-docs/` 及内容
- [ ] `tests/repos/test-subagents/` 及内容

---

## 阶段 4: 更新文档

### 文件变更

| 文件 | 操作 |
|------|------|
| CLAUDE.md | 重写（新架构） |
| README.md | 简化（curl 安装） |
| docs/ARCHITECTURE.md | 更新架构图 |
| legacy/docs/plans/migration/OLD-plan.md | 归档（旧计划） |
| docs/migration/plan.md | 重写（新计划） |

### 待完成

- [ ] 重写 CLAUDE.md
- [ ] 简化 README.md
- [ ] 更新 docs/ARCHITECTURE.md
- [ ] 移动旧 plan

---

## 阶段 5: 备份与清理

### 备份

```bash
git checkout -b backup/python-legacy
git push origin backup/python-legacy
git checkout main
````

### 删除

```
legacy-python-runtime/router.py      # 路由逻辑（迁移到 Skill）
legacy-python-runtime/acp_adapter.py # acpx 执行（改用直接 CLI）
legacy-python-runtime/validator.py   # 验证器（Skill 内处理）
legacy-python-runtime/config.py     # 配置加载（repo_mappings.json 替代）
legacy-python-runtime/__init__.py    # 精简
legacy-python-runtime/cli.py         # 删除
legacy-python-runtime/init.py        # 删除
demo.py               # 删除
pyproject.toml        # 删除
skills/agent-repo-router/router.py  # 依赖 legacy-python-runtime/，需删除
```

### 保留

```
tests/                    # 测试用例
legacy/config/            # 配置示例（参考用）
skills/agent-repo-router/SKILL.zh.md # Router Skill (中文模板)
skills/agent-repo-router/SKILL.en.md # Router Skill (英文模板)
skills/agent-repo-router/references/  # 配置文件
```

### 待完成

- [ ] 备份到 `backup/python-legacy` 分支
- [ ] 删除废弃 Python 代码
- [ ] 删除 demo.py, pyproject.toml
- [ ] 删除 skills/agent-repo-router/router.py

---

## 阶段 6: 测试验证

### 测试场景

#### 1. install.sh 测试

```bash
# 验证：交互式完成初始化
# 验证：repo_mappings.json 生成正确
# 验证：SKILL.md 部署成功
```

#### 2. Auto Scan 测试

```bash
# 输入 ~/projects
# 验证：发现所有 .git 目录
# 验证：项目名正确提取
```

#### 3. Router Skill 测试

| 场景                    | 测试内容                                                   |
| ----------------------- | ---------------------------------------------------------- |
| Claude Code 调用        | `cd /path && claude -p "task"`                             |
| Claude Code sub-agent   | `cd /path && claude --agent bugfix "task"`                 |
| OpenCode 调用           | `cd /path && opencode run "task"`                          |
| Cursor 调用             | `cd /path && agent -p "task"`                              |
| 自定义 agent (Claude)   | `~/.claude/agents/bugfix.md` 存在，`--agent <name>` 可调用 |
| 自定义 agent (OpenCode) | `~/.config/opencode/agents/` 配置，提示词 `use agent xxx`  |
| 自定义 agent (Cursor)   | `~/.cursor/agents/` 配置，提示词 `use agent xxx`           |
| Skill 调用              | `use skill <name> to solve...`                             |
| Fallback                | 第一个 CLI 不可用时自动尝试下一个                          |
| 任务类型分类            | bugfix/docs/qa/feature/review 正确路由                     |
| 找不到匹配              | 使用默认 agent                                             |
| Agent/Skill 冲突        | 提示用户选择                                               |
| Skill 语言选择          | 中文/English Skill 正确 rename                             |

#### 4. 边界场景测试

| 场景             | 测试内容                |
| ---------------- | ----------------------- |
| 无效路径         | 提示重新输入            |
| 重复项目名       | 过滤保留一个            |
| 无 CLI 可用      | 报错退出                |
| Skill/Agent 冲突 | 提示用户选择            |
| Skill 执行失败   | Fallback 到下一个 agent |

### 待完成

- [ ] 测试 install.sh
- [ ] 测试 Auto Scan
- [ ] 测试 Router Skill
- [ ] 测试所有 CLI 调用
- [ ] 测试自定义 agents
- [ ] 测试 Skill 调用
- [ ] 测试 Agent/Skill 冲突处理
- [ ] 测试 Fallback 机制
- [ ] 测试 Skill 语言选择（rename 逻辑）
- [ ] 测试边界场景

---

## 文件变更清单

### 新增

```
~/.openclaw/skills/agent-repo-router/SKILL.md                      # 路由 Skill
~/.openclaw/skills/agent-repo-router/references/repo_mappings.json # 运行时配置
scripts/install.sh              # 主安装脚本
tests/repos/test-backend/       # 测试仓库
tests/repos/test-docs/          # 测试仓库
tests/repos/test-subagents/    # 测试仓库
```

### 删除

```
legacy-python-runtime/router.py
legacy-python-runtime/acp_adapter.py
legacy-python-runtime/validator.py
legacy-python-runtime/config.py
legacy-python-runtime/cli.py
legacy-python-runtime/init.py
legacy-python-runtime/__init__.py
demo.py
pyproject.toml
skills/agent-repo-router/router.py
```

### 移动

```
legacy/docs/plans/migration/OLD-plan.md  # 原 plan.md
```

### 保留

```
tests/
legacy/config/
skills/agent-repo-router/SKILL.zh.md
skills/agent-repo-router/SKILL.en.md
skills/agent-repo-router/references/
```

---

## 执行顺序

1. ⬜ 重写 `install.sh`
2. ⬜ 创建 `skills/agent-repo-router/SKILL.zh.md` 和 `skills/agent-repo-router/SKILL.en.md`
3. ⬜ 创建 `skills/agent-repo-router/references/repo_mappings.json`
4. ⬜ 创建测试仓库 `tests/repos/`
5. ⬜ 更新文档
6. ⬜ 备份到 `backup/python-legacy` 分支
7. ⬜ 清理废弃 Python 代码
8. ⬜ 测试验证

---

## 验收标准

- [ ] `install.sh` 交互式完成初始化
- [ ] `repo_mappings.json` 正确生成到 `router/references/`
- [ ] Router Skill 正确路由任务
- [ ] Fallback 按 executionClis 顺序尝试
- [ ] 文档准确反映新架构
- [ ] Python 代码完全不参与运行时
- [ ] 所有 CLI 命令正确执行（统一用 `cd` 切换目录）
- [ ] 自定义 agents 路径正确配置
- [ ] Agent/Skill 调用规范正确（含省略规则和冲突处理）
- [ ] Skill 语言选择功能正常（rename 逻辑）
