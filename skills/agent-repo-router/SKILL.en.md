---
name: agent-repo-router
description: "Route coding tasks to the right repo and CLI."
---

# AgentRepoRouter Skill

Read `references/repo_mappings.json` for the repo list, repo aliases, detected project-level skills, detected project-level agents, install hosts, and default execution CLI order.

See `references/guide.en.md` for detailed CLI conventions, path conventions, and longer examples.

## Decision Order

1. Determine the target repo first.
   - If the user explicitly names a project, prefer that project.
   - Otherwise choose the best repo from `repo_mappings.json` using the repo name, task context, and any configured `aliases`.
   - Only ask the user when there is no reliable repo choice.
2. Check project-level Skills and Agents inside the chosen repo first.
   - If the repo `skills` field already lists a relevant project-level skill and description for a CLI, treat that as a strong hint.
   - If the repo `agents` field already lists a relevant project-level agent and description for a CLI, treat that as a strong hint.
   - Use each CLI's native conventions when looking for project-level assets.
   - See `references/guide.en.md` for the concrete paths and caveats.
3. Only if project-level assets do not match reliably, consider global Skills and Agents.
   - Global matches must be strict.
   - Do not inject a global Skill or Agent on weak or generic similarity.
4. If neither project-level nor global matches are reliable, fall back to the default `executionClis` order from `repo_mappings.json`.

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
| Hermes                  | `cd /path && hermes --oneshot "task"` |

## references/repo_mappings.json

The configuration file defines:

- `repos`: the candidate projects for routing, plus optional aliases and detected skills and agents
- `executionClis`: the default CLI fallback order
- `installMode` and `installHosts`: where this skill was installed

```json
{
  "schemaVersion": 2,
  "installMode": "global",
  "installHosts": ["global", "openclaw", "claude-code", "opencode", "codex", "hermes"],
  "executionClis": ["claude-code", "opencode", "cursor", "codex", "hermes"],
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
