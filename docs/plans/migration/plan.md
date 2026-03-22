# OrchAI 迁移实现计划

> ⚠️ **待 Review** - 此计划需用户确认后执行

---

## 概述

将 OrchAI 从 Python 运行时框架迁移到**纯 Shell 初始化 + OpenClaw Skill 运行时**架构。

```
install.sh → init → OpenClaw Skill (运行时)
```

---

## 最终设计要点

| 项目 | 决策 |
|------|------|
| CLI 调用 | 直接 CLI，不用 acpx |
| Fallback | 用户勾选顺序，写入 repo_mappings.json |
| 路由 | LLM 判断（不是关键词匹配） |
| init | Shell 脚本（不是 Python） |
| 项目发现 | Auto scan `.git` + Manual 路径列表 |

---

## 阶段 1: 更新 install.sh

### 目标

`install.sh` 负责安装依赖和初始化配置。

### 流程

```
install.sh
│
├── 1. 检查环境（Node.js 18+, Git, npm）
│
├── 2. 安装 OpenClaw
│   └── npm install -g openclaw
│
├── 3. 用户选择 CLI（交互式）
│   ├── [ ] claude-code
│   ├── [ ] opencode
│   ├── [ ] cursor
│   └── [ ] codex
│
├── 4. 项目发现
│   ├── 选项 A: Auto scan
│   │   └── 输入根目录路径 → 扫描 .git 子目录
│   └── 选项 B: Manual
│       └── 输入项目绝对路径列表
│
├── 5. 生成 ~/.orchai/repo_mappings.json
│   └── 包含 agents 顺序和 repos 列表
│
└── 6. 部署 router Skill
    └── 创建 ~/.openclaw/skills/router/SKILL.md
```

### 生成的 repo_mappings.json

```json
{
  "agents": ["claude-code", "opencode", "cursor", "codex"],
  "repos": [
    {
      "name": "my-backend",
      "path": "/path/to/backend",
      "auto_discovered": true
    }
  ]
}
```

### 待完成

- [ ] 交互式 CLI 选择
- [ ] Auto scan 逻辑（扫描 .git 目录）
- [ ] Manual 路径输入
- [ ] 生成 repo_mappings.json
- [ ] 部署 SKILL.md

---

## 阶段 2: 创建 router/SKILL.md

### 目标

OpenClaw Skill 负责运行时路由和执行。

### 文件位置

```
~/.openclaw/skills/router/SKILL.md
```

### SKILL.md 内容

```markdown
---
name: router
description: Route coding tasks to appropriate repos and agents. Use when user wants to work on a project or perform a coding task.
---

# Router Skill

读取 `~/.orchai/repo_mappings.json` 获取配置。

## 配置格式

```json
{
  "agents": ["claude-code", "opencode", "cursor", "codex"],
  "repos": [...]
}
```

## 工作流程

### 1. 理解任务
分析用户任务，确定：
- 任务类型（bugfix, feature, refactor, docs, review）
- 目标项目（如未指定，询问用户）

### 2. 选择 Agent
按 repo_mappings.json 中的 agents 顺序，选择第一个可用的：
- claude-code: 通用任务
- opencode: 特定场景
- cursor: 特定场景
- codex: 特定场景

### 3. 选择项目
如用户未指定，从 repos 列表中选择最相关的。

### 4. 执行命令

```bash
# Claude Code
claude -p "task description"

# OpenCode
opencode run "task description"

# Cursor
cursor-agent -p "task description"

# Codex
codex "task description"
```

### 5. Fallback
如果第一个 Agent 不可用或失败，自动尝试下一个。

## 任务类型提示

- **bugfix**: "fix", "bug", "error", "issue"
- **feature**: "add", "implement", "create", "new"
- **refactor**: "refactor", "clean", "improve"
- **docs**: "doc", "readme", "guide", "document"
- **review**: "review", "check", "audit"
```

---

## 阶段 3: 迁移现有 Skills

从 `tests/repos/` 迁移已验证的 skills 到 `skills/`：

| Skill | 来源 | 目标 |
|-------|------|------|
| build_and_test | tests/repos/test-backend/.claude/skills/ | skills/build_and_test |
| bug-fix | tests/repos/test-backend/.opencode/skills/ | skills/bug-fix |
| doc-writer | tests/repos/test-docs/.claude/skills/ | skills/doc-writer |
| code-review | (新) | skills/code-review |

待迁移：
- [ ] 整理 build_and_test/SKILL.md
- [ ] 整理 bug-fix/SKILL.md
- [ ] 整理 doc-writer/SKILL.md
- [ ] 创建 code-review/SKILL.md

---

## 阶段 4: 文档更新

- [ ] 更新 `CLAUDE.md` — 新架构说明
- [ ] 更新 `README.md` — 简化安装和使用
- [ ] 更新 `docs/ARCHITECTURE.md` — 新架构图
- [ ] 创建 `docs/MIGRATION.md` — 迁移指南

---

## 阶段 5: 备份与清理

### 备份

```bash
git checkout -b backup/python-legacy
git push origin backup/python-legacy
```

### 删除

```
orchai/router.py      # 路由逻辑（迁移到 Skill）
orchai/acp_adapter.py # acpx 执行（改用直接 CLI）
orchai/validator.py   # 验证器（Skill 内处理）
orchai/config.py     # 配置加载（repo_mappings.json 替代）
orchai/__init__.py    # 精简
orchai/cli.py         # 删除
orchai/init.py        # 删除
```

### 保留

```
tests/                    # 测试用例
config/                   # 配置示例（参考用）
demo.py                   # 可选删除
pyproject.toml           # 可选删除
```

---

## 阶段 6: 测试验证

### 测试 1: install.sh
```bash
curl -fsSL https://.../install.sh | bash
# 验证：repo_mappings.json 生成正确
# 验证：SKILL.md 部署成功
```

### 测试 2: Router Skill
```bash
openclaw
> router
> 在 my-backend 项目上 fix login bug
# 验证：正确选择项目和 agent
# 验证：fallback 机制工作
```

### 测试 3: Auto scan
```bash
# 输入 ~/projects
# 验证：发现所有 .git 目录
```

---

## 文件变更清单

### 新增
```
~/.orchai/repo_mappings.json    # 用户目录下
~/.openclaw/skills/router/SKILL.md  # 路由 Skill
scripts/install.sh              # 主安装脚本（重写）
skills/*.md                     # 迁移的 skills
```

### 删除
```
orchai/router.py
orchai/acp_adapter.py
orchai/validator.py
orchai/config.py
orchai/cli.py
orchai/init.py
orchai/__init__.py
```

### 保留
```
tests/
config/
```

---

## 执行顺序

1. ⬜ 重写 `install.sh`（交互式 CLI 选择 + 项目发现）
2. ⬜ 创建 `~/.openclaw/skills/router/SKILL.md`
3. ⬜ 迁移 skills 到 `skills/` 目录
4. ⬜ 更新文档
5. ⬜ 备份到 `backup/python-legacy` 分支
6. ⬜ 清理废弃 Python 代码
7. ⬜ 测试验证

---

## 验收标准

- [ ] `install.sh` 交互式完成初始化
- [ ] `repo_mappings.json` 正确生成
- [ ] Router Skill 正确路由任务
- [ ] Fallback 按 agents 顺序尝试
- [ ] 文档准确反映新架构
- [ ] Python 代码完全不参与运行时
