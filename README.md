# OrchAI

AI coding agent orchestration via an OpenClaw Router Skill.

## Quick Start

```bash
# Install from GitHub
curl -fsSL https://raw.githubusercontent.com/wufei-png/OrchAI/main/scripts/install.sh | bash

# Or local install
bash scripts/install.sh

# Edit config
vim ~/.openclaw/skills/router/references/repo_mappings.json

# Start OpenClaw
openclaw
```

## What Exists Today

- `scripts/install.sh` checks Node.js 18+, Git, and OpenClaw
- The installer lets you choose language and supported CLIs
- Project discovery supports auto scan and manual absolute paths
- The generated repo config includes empty `aliases` plus detected project skill and agent summaries
- The installer writes `~/.openclaw/skills/router/references/repo_mappings.json`
- The selected router variant is deployed as `~/.openclaw/skills/router/SKILL.md`

## Runtime Shape

```text
User -> OpenClaw -> Router Skill -> cd into repo -> direct CLI
```

## Supported CLIs

| CLI | Non-interactive task command | Project or custom config |
| --- | --- | --- |
| Claude Code | `claude -p "task"` | `~/.claude/agents/`, `<repo>/.claude/agents/` |
| OpenCode | `opencode run "task"` | `~/.config/opencode/agents/`, `<repo>/.opencode/agents/` |
| Cursor | `agent -p "task"` | `~/.cursor/agents/`, `<repo>/.cursor/agents/` |
| Codex | `codex exec "task"` | `~/.codex/config.toml`, `.codex/config.toml`, `~/.codex/agents/`, `.codex/agents/`, `.agents/skills/`, `AGENTS.md` |

Codex also supports `codex exec -C /path/to/repo "task"` officially. OrchAI documentation still uses `cd /path && ...` examples so the routing pattern stays uniform across CLIs.

## Example

```bash
# Claude Code
cd tests/repos/test-backend && claude -p "fix login bug"

# OpenCode
cd tests/repos/test-docs && opencode run "write documentation"

# Codex
cd tests/repos/test-backend && codex exec "review the auth flow"
```

## Documentation

- [CLAUDE.md](CLAUDE.md) - Full project context
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) - Current architecture and runtime conventions
- [docs/PRODUCT.md](docs/PRODUCT.md) - Future roadmap, not current implementation
- [docs/plans/migration/plan.md](docs/plans/migration/plan.md) - Migration history and implementation plan
- [legacy/README.md](legacy/README.md) - Archived legacy materials
