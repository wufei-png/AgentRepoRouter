---
name: router
description: "Route coding tasks to appropriate repos and agents. Use when user wants to work on a project or perform a coding task."
---

# Router Skill

Read `references/repo_mappings.json` for the repo list and default agents order.

See `references/guide.en.md` for detailed CLI conventions, path conventions, and longer examples.

## Decision Order

1. Determine the target repo first.
   - If the user explicitly names a project, prefer that project.
   - Otherwise choose the best repo from `repo_mappings.json`.
   - Only ask the user when there is no reliable repo choice.
2. Check project-level Skills and Agents inside the chosen repo first.
   - Use each CLI's native conventions when looking for project-level assets.
   - See `references/guide.en.md` for the concrete paths and caveats.
3. Only if project-level assets do not match reliably, consider global Skills and Agents.
   - Global matches must be strict.
   - Do not inject a global Skill or Agent on weak or generic similarity.
4. If neither project-level nor global matches are reliable, fall back to the default CLI order from `repo_mappings.json`.

## Invocation Rules

- Claude Code custom agents can use `--agent <name>`.
- OpenCode and Cursor custom agents must use the prompt form `use agent <name> to do...`.
- Unified skill prompt:

```text
use skill <skill-name> to solve the following task: <task description>
```

- If only one of skill or agent clearly matches, the other can be omitted.
- If a skill and an agent give clearly conflicting instructions, ask the user instead of mixing them blindly.

## Minimal Command Templates

> Use `cd /path && ...` to change working directory before running the CLI.

| CLI                     | Command |
| ----------------------- | ------- |
| Claude Code             | `cd /path && claude -p "task"` |
| Claude Code (sub-agent) | `cd /path && claude --agent <name> "task"` |
| OpenCode                | `cd /path && opencode run "task"` |
| Cursor                  | `cd /path && agent -p "task"` |
| Codex                   | `cd /path && codex exec "task"` |

## references/repo_mappings.json

The configuration file defines only:

- `repos`: the candidate projects for routing
- `agents`: the default fallback order

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
