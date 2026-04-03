---
name: router
description: "Route coding tasks to appropriate repos and agents. Use when user wants to work on a project or perform a coding task."
---

# Router Skill

Read `references/repo_mappings.json` for configuration.

## CLI Command Format

> Use `cd` to change working directory

| Agent                   | Command                        | Working Directory                          |
| ----------------------- | ------------------------------ | ------------------------------------------ |
| Claude Code             | `claude -p "task"`             | `cd /path && claude -p "task"`             |
| Claude Code (sub-agent) | `claude --agent <name> "task"` | `cd /path && claude --agent <name> "task"` |
| OpenCode                | `opencode run "task"`          | `cd /path && opencode run "task"`          |
| Cursor                  | `agent -p "task"`              | `cd /path && agent -p "task"`              |

## Custom Agent Paths

| Tool        | Global Path                  | Project Path               | Native CLI          | Prompt-based       |
| ----------- | ---------------------------- | -------------------------- | ------------------- | ------------------ |
| Claude Code | `~/.claude/agents/`          | `<repo>/.claude/agents/`   | ✅ `--agent <name>` | ✅ `use agent xxx` |
| OpenCode    | `~/.config/opencode/agents/` | `<repo>/.opencode/agents/` | ❌                  | ✅ `use agent xxx` |
| Cursor      | `~/.cursor/agents/`          | `<repo>/.cursor/agents/`   | ❌                  | ✅ `use agent xxx` |

> **Note**: Cursor and OpenCode custom agents can only be invoked via **prompt**, not CLI arguments.

## Agent and Skill Invocation Rules

### Custom Agent Invocation

- **Claude Code**: Use `--agent <name>` parameter
- **OpenCode / Cursor**: Use `use agent <name> to do...` in prompt

### Skill Invocation (Unified)

```
use skill <skill-name> to solve the following task: <task description>
```

### Agent/Skill Omission Rules

| Situation                                   | Prompt写法                 |
| ------------------------------------------- | -------------------------- |
| Agent/Skill in agent folder, only one match | Omit                       |
| Only one Agent/Skill matches                | `use skill` or `use agent` |
| Both Agent and Skill match                  | Use both                   |
| Agent and Skill conflict                    | Prompt user to decide      |

### Agent and Skill Priority

Decide in this order:

1. **Prefer project-level Skills and Agents**
   - Check custom Skills and Agents inside the target repo first
   - For example `<repo>/.claude/skills/`, `<repo>/.claude/agents/`, `<repo>/.opencode/skills/`, `<repo>/.opencode/agents/`
   - If a project-level Skill and Agent both match, use the Skill first and include the Agent as well

2. **Consider global Skills and Agents only after project-level misses**
   - Only when no suitable project-level match exists should global Skills or Agents be considered
   - Global configuration is second priority and must not override a clear project-level match

3. **Require stricter matching for global configuration**
   - Only use a global Skill / Agent when the name is highly specific, the task strongly matches its responsibility, or the user explicitly asks for it
   - Do not inject a global Skill / Agent on weak or generic matches

4. **Fallback to default last**
   - If neither project-level nor global matches are reliable, fallback to the default agents order from `repo_mappings.json`
   - Do not force a Skill in this case unless the Skill match is very explicit

## Workflow

### 1. Understand Task

Analyze user's task to determine:

- Task type (bugfix, feature, refactor, docs, qa, review)
- Target project (ask user if not specified)
- Matched Agent and Skill

### 2. Select Agent and Skill

Decide in this order:

1. Match project-level Skills and Agents first
2. Only if project-level misses, consider global Skills and Agents
3. Apply a stricter threshold for global matches
4. If nothing reliable matches, fallback to the default agents order in `repo_mappings.json`

### 3. Execute Command

```bash
# Claude Code
cd /path/to/repo && claude -p "task description"

# Claude Code (sub-agent)
cd /path/to/repo && claude --agent bugfix "task description"

# OpenCode / Cursor (prompt-based agent)
cd /path/to/repo && opencode run "use agent xxx to do: task description"

# Skill invocation (unified format)
cd /path/to/repo && opencode run "use skill <skill-name> to solve: task description"
```

### 4. Fallback

If the first Agent is unavailable or fails, automatically try the next one.

### 5. Task Type Classification

| Type     | Keywords                    |
| -------- | --------------------------- |
| bugfix   | fix, bug, error, issue      |
| feature  | add, implement, create, new |
| refactor | refactor, clean, improve    |
| docs     | doc, readme, guide          |
| qa       | question, how, what, why    |
| review   | review, check, audit        |

### 6. No Match Handling

If user's task doesn't match any agent or skill:

1. Use default agent (first in agents list)
2. Execute general task

## references/repo_mappings.json

Configuration file defining agents order and repos list.

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
