---
name: router
description: "路由编码任务到合适的仓库和 Agent。当用户想要在某个项目上工作或执行编码任务时使用。"
---

# Router Skill

读取 `references/repo_mappings.json` 获取仓库列表、repo aliases、已检测的 project-level skills，以及默认 agents 顺序。

详细 CLI 约定、路径约定和更多示例见 `references/guide.zh.md`。

## 决策顺序

1. 先确定目标 repo。
   - 如果用户已经明确指定项目，优先使用用户指定项目。
   - 如果未指定，再根据任务内容、repo name、以及 `aliases` 从 `repo_mappings.json` 的 repos 中选择最合适的项目。
   - 只有在没有可靠项目时才询问用户，不要过早提问。
2. 在目标 repo 内先检查项目级 Skill 和 Agent。
   - 如果 `skills` 字段已经列出了某个 CLI 下的 project-level skill 及 description，把它当作强提示。
   - 按对应 CLI 的原生约定检查项目级资产。
   - 具体路径和命令细节见 `references/guide.zh.md`。
3. 项目级未命中时，再考虑全局 Skill 和 Agent。
   - 全局命中必须严格，不要因为弱相关或泛匹配就附加全局能力。
4. 如果项目级和全局级都没有可靠命中，则按 `repo_mappings.json` 中的 `agents` 顺序 fallback 到默认 CLI。

## 调用规则

- Claude Code 的自定义 agent 可以用 `--agent <name>`。
- OpenCode / Cursor 的自定义 agent 只能用提示词 `use agent <name> to do...`。
- 统一 skill 提示词：

```text
use skill <skill-name> to solve the following task: <task description>
```

- 如果只明确命中一个 skill 或 agent，可以省略另一项。
- 如果 skill 和 agent 指令明显冲突，提示用户选择，不要擅自混用。

## 最小命令模板

> 统一使用 `cd /path && ...` 切换工作目录。

| CLI                     | 命令 |
| ----------------------- | ---- |
| Claude Code             | `cd /path && claude -p "task"` |
| Claude Code (sub-agent) | `cd /path && claude --agent <name> "task"` |
| OpenCode                | `cd /path && opencode run "task"` |
| Cursor                  | `cd /path && agent -p "task"` |
| Codex                   | `cd /path && codex exec "task"` |

## references/repo_mappings.json

配置文件只定义两件事：

- `repos`: 可供路由选择的项目列表，以及可选 aliases 与已检测 skills
- `agents`: 默认 fallback 顺序

```json
{
  "schemaVersion": 1,
  "agents": ["claude-code", "opencode", "cursor", "codex"],
  "repos": [
    {
      "name": "project-name",
      "path": "/path/to/project",
      "aliases": ["project", "backend"],
      "skills": {
        "claude-code": [
          {
            "name": "build_and_test",
            "description": "Run build and tests before finishing changes."
          }
        ]
      }
    }
  ]
}
```
