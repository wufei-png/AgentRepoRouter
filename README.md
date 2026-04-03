# OrchAI

AI Coding Agent Orchestrator via OpenClaw Skill

## Quick Start

```bash
# Install
curl -fsSL https://.../install.sh | bash

# Or local install
bash scripts/install.sh

# Edit config
vim ~/.openclaw/skills/router/references/repo_mappings.json

# Start
openclaw
```

## Architecture

```
User → OpenClaw → Router Skill → Agent (direct CLI)
```

## Features

- **Direct CLI**: No middle protocol layer
- **Intelligent Routing**: LLM-based task classification
- **Multi-Agent Support**: claude-code, opencode, cursor, codex
- **Project Isolation**: Each project has independent workspace
- **Bilingual**: install.sh deploys the selected language as `SKILL.md`

## Example

```bash
# Router decides: test-backend + Claude Code
cd tests/repos/test-backend && claude -p "fix login bug"

# Or with OpenCode
cd tests/repos/test-docs && opencode run "write documentation"
```

## Supported Agents

| Agent       | Command               | Custom Agent Path            |
| ----------- | --------------------- | ---------------------------- |
| Claude Code | `claude -p "task"`    | `~/.claude/agents/`          |
| OpenCode    | `opencode run "task"` | `~/.config/opencode/agents/` |
| Cursor      | `agent -p "task"`     | `~/.cursor/agents/`          |

## Documentation

- [CLAUDE.md](CLAUDE.md) - Full project context
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) - System architecture
- [docs/plans/migration/plan.md](docs/plans/migration/plan.md) - Migration plan
- [legacy/README.md](legacy/README.md) - Archived legacy materials
