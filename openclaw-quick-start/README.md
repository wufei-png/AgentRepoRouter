# OpenClaw Quick Start

Simple, shell-based AI Coding Agent setup using OpenClaw + acpx.

## What This Is

A minimal replacement for complex Python-based agent orchestration. Just:
1. Install once with `install.sh`
2. Run any agent directly: `npx acpx@latest opencode --cwd myproject "fix bug"`
3. Or use the simple `router.sh` for keyword-based routing

## Architecture

```
User → acpx → Agent (claude-code/opencode/codex)
           ↓
      Project Skills (.claude/skills/, .opencode/skills/)
```

That's it. No Python framework, no complex config.

## Quick Start

```bash
# One-time installation
cd openclaw-quick-start
./install.sh

# Configure OpenClaw (first time only)
openclaw configure

# Run a task directly
cd your-project
npx acpx@latest opencode "fix login bug"

# Or use router
./scripts/router.sh "fix login bug"
```

## Project Structure

```
openclaw-quick-start/
├── install.sh           # One-click installer
├── openclaw.json        # OpenClaw config
├── skills/              # Global skills
│   ├── build_and_test/
│   ├── bug-fix/
│   ├── doc-writer/
│   └── code-review/
├── scripts/
│   ├── router.sh        # Simple keyword router
│   └── repo_mappings.json
└── projects/            # Your projects
    └── default/
```

## Skills

Skills are standard OpenClaw SKILL.md files in:
- Global: `skills/<name>/SKILL.md`
- Project: `your-project/.claude/skills/<name>/SKILL.md`
- OpenCode: `your-project/.opencode/skills/<name>/SKILL.md`

## Adding Projects

Edit `scripts/repo_mappings.json`:

```json
{
  "repos": [
    {
      "name": "my-backend",
      "path": "/path/to/my-backend",
      "keywords": ["backend", "api", "auth"],
      "description": "Backend service"
    }
  ]
}
```

## Agent Selection (auto by router.sh)

| Task Keywords | Agent |
|--------------|-------|
| fix, bug, error | opencode |
| add, implement, create | claude-code |
| refactor, improve | claude-code |
| doc, readme, guide | codex |
| review, check | claude-code |

Or force with `-a` flag:
```bash
./scripts/router.sh -a opencode "fix bug"
```

## Direct Agent Usage

```bash
# Claude Code
npx acpx@latest claude-code --cwd myproject "add feature"

# OpenCode
npx acpx@latest opencode --cwd myproject "fix bug"

# Codex
npx acpx@latest codex --cwd myproject "write docs"
```

## Requirements

- Node.js 18+
- npm
- Git (acpx requires git repos)
- One of: claude-code, opencode-ai, or @openai/codex installed
