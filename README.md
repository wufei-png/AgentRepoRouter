# AgentRepoRouter

[中文版](README_CN.md) | English

Repo-aware routing for AI coding CLIs as an installable skill for multiple agent hosts.

AgentRepoRouter installs into OpenClaw, Claude Code, OpenCode, Codex, and Hermes skill locations. It does not replace those tools. It routes tasks to the right repo, preserves each CLI's native agent and skill conventions, and uses structured repo metadata to improve navigation.

## Why AgentRepoRouter Exists

Many developers now have more than one coding CLI, more than one repo, and more than one place where custom agents or skills live.

The real problem is often not "how do I run 20 agents in parallel?" It is:

- Which repo should this task run in?
- Which CLI is the best fit for this repo?
- Does this repo already contain a project-level skill or agent I should use first?
- How do I keep one agent-host entry point without flattening away each CLI's native conventions?

AgentRepoRouter is built for that gap.

## Positioning

The best way to understand AgentRepoRouter is:

- OpenClaw, Claude Code, OpenCode, Codex, or Hermes can host the skill.
- AgentRepoRouter is the routing layer for coding work.
- Claude Code, OpenCode, Cursor, Codex, and Hermes stay as the execution backends.

This means AgentRepoRouter is intentionally lighter than a full orchestration runtime. It focuses on entry, routing, repo selection, and native CLI invocation rather than boards, worktrees, PR lifecycle automation, or parallel swarms.

## Research Conclusion

This round of repo research led to three practical conclusions:

- AgentRepoRouter's value is not "beating" heavy orchestrators. Its value is being the thin but useful layer that makes agent hosts repo-aware and CLI-aware for real coding tasks.
- The most important differentiator is preserving native CLI ecosystems instead of inventing a new abstraction that hides them.
- With `aliases`, detected project `skills`, and detected project `agents` now embedded in `repo_mappings.json`, AgentRepoRouter is no longer just a thin prompt wrapper. It becomes structured routing context that supported hosts can navigate reliably.

## Quick Start

```bash
# Install from GitHub
curl -fsSL https://raw.githubusercontent.com/wufei-png/AgentRepoRouter/main/scripts/install.sh | bash

# Or local install
bash scripts/install.sh

# Review repo aliases and detected project assets
vim ~/.agents/skills/agent-repo-router/references/repo_mappings.json

# Start your host, for example OpenClaw
openclaw
```

## Runtime Shape

```text
User
  -> OpenClaw / Claude Code / OpenCode / Codex / Hermes
  -> Router Skill
  -> repo match via repo name / alias / task intent
  -> project-level skill / agent hints from repo_mappings.json
  -> direct native CLI execution
```

## What Exists Today

- `scripts/install.sh` checks Node.js 18+ and Git, then detects supported agent hosts.
- The installer lets you choose language, install mode, install hosts, and execution CLIs separately.
- Default install mode is global: write once to `~/.agents/skills/agent-repo-router` and symlink detected hosts.
- Single-host mode installs directly into the selected host skill directory.
- Custom-host mode writes the canonical global copy and symlinks selected hosts.
- Project discovery supports auto scan and manual absolute paths.
- The generated repo config includes `aliases`, detected project-level `skills`, and detected project-level `agents`.
- The installer writes schema v2 `repo_mappings.json` with `installMode`, `installHosts`, and `executionClis`.
- The repo includes unit, integration, and E2E tests plus opt-in live OpenClaw E2E coverage.

## Design Principles

### 1. Host-Native Installation

AgentRepoRouter is delivered as a skill, not as another daemon or control plane. It can be installed directly for one host or installed once globally and linked into multiple host skill directories.

### 2. Repo Metadata Is First-Class

Routing quality depends on repo context. `repo_mappings.json` is therefore not just a list of paths. It is a small routing catalog:

```json
{
  "schemaVersion": 2,
  "installMode": "global",
  "installHosts": ["global", "openclaw", "claude-code", "opencode", "codex", "hermes"],
  "executionClis": ["claude-code", "opencode", "cursor", "codex", "hermes"],
  "repos": [
    {
      "name": "example-backend",
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

### 3. Preserve Native CLI Conventions

Each CLI already has its own invocation model and project asset conventions. AgentRepoRouter keeps those differences visible and uses them rather than hiding them.

- Claude Code: `claude -p "task"` or `claude --agent <name> "task"`
- OpenCode: `opencode run "task"` with prompt-based agent selection
- Cursor: `agent -p "task"` with prompt-based agent selection
- Codex: `codex exec "task"` with project-level `.agents/skills/`, `.codex/agents/`, and `AGENTS.md`
- Hermes: `hermes --oneshot "task"` with Hermes skill conventions

### 4. Project-Level Assets Come Before Global Defaults

If a repo already has a project-level skill or agent, that should be treated as a strong hint before any global helper is attached.

### 5. Explicit Fallback Beats Hidden Magic

If nothing matches reliably, AgentRepoRouter falls back using the `executionClis` order in `repo_mappings.json`. The behavior stays inspectable and predictable.

## Why The Current Schema Matters

The newer `aliases` and detected `skills` and `agents` fields directly improve routing in ways the earlier minimal schema could not:

- `aliases` lets the host match user language to repo nicknames such as `api`, `docs`, or `admin`.
- `skills` gives the router project-level capability hints before the CLI even starts.
- `agents` gives the router project-level specialist hints without forcing weak global matches.
- The `references/` folder keeps the runtime skill short while moving longer CLI conventions into explicit reference docs.

## Comparison

The projects below are good comparison points, but they optimize for different layers of the stack.

| Project | Primary role | Execution model | What it optimizes for | How it differs from AgentRepoRouter |
| --- | --- | --- | --- | --- |
| [AgentRepoRouter](https://github.com/wufei-png/AgentRepoRouter) | Repo-aware routing skill for multiple agent hosts | One skill chooses repo, skill, agent, and CLI, then calls the native CLI directly | Unified entry and predictable routing across multiple coding CLIs | Focuses on routing and native convention preservation instead of full orchestration |
| [OpenClaw](https://github.com/openclaw/openclaw) | Local-first personal assistant and control plane | Sessions, channels, skills, tools, and agents under one assistant runtime | Communication surfaces, sessions, skills, local-first assistant behavior | AgentRepoRouter is a coding-focused skill on top of OpenClaw, not a replacement |
| [MCO](https://github.com/mco-org/mco) | Parallel multi-CLI orchestration | Dispatch the same prompt to multiple coding CLIs and synthesize the results | Fan-out review, consensus, multi-model comparison | AgentRepoRouter chooses one best-fit path first; MCO is better when you want parallel review or consensus |
| [agtx](https://github.com/fynnfluegge/agtx) | Multi-agent task board and lifecycle manager | Kanban board, tmux sessions, worktrees, and orchestration agent | Persistent task flow across many agent sessions | AgentRepoRouter is much lighter and does not own task boards or worktree lifecycles |
| [Agent Orchestrator](https://github.com/ComposioHQ/agent-orchestrator) | Autonomous PR and CI workflow automation | Dashboard plus agents in isolated worktrees reacting to CI and review feedback | Ticket-to-PR automation at scale | AgentRepoRouter stays as a routing layer and avoids taking over the whole delivery lifecycle |
| [metaswarm](https://github.com/dsifry/metaswarm) | Opinionated SDLC orchestration framework | Multi-phase workflow, many personas, review gates, recursive orchestration | Strong process control and self-improving delivery loops | AgentRepoRouter is less opinionated, simpler to adopt, and easier to layer onto an existing OpenClaw setup |
| [burn-harness](https://github.com/bkmashiro/burn-harness) | Continuous developer task queue for coding agents | Background loop pulls tasks, executes work, creates draft PRs, retries failures | Non-stop task throughput | AgentRepoRouter is interactive and routing-oriented rather than a background worker queue |

## Highlights

- Multi-host deployment: install once globally and link detected hosts, or install directly for one host.
- Repo-aware navigation: repo names, aliases, and task intent all contribute to routing.
- Structured project hints: detected project-level skills and agents are stored in config instead of living only in prompt text.
- Low lock-in: the execution step is still the original CLI, not a custom wrapper protocol.
- Native conventions preserved: AgentRepoRouter adapts to Claude Code, OpenCode, Cursor, Codex, and Hermes instead of pretending they are identical.
- Short runtime skill, longer references: the active `SKILL.md` stays readable while `references/` holds the detailed conventions.
- Installer plus validation: repo config is generated and validated automatically.
- Tested baseline: the repo includes unit, integration, E2E, and opt-in live tests.

## Supported CLIs

| CLI | Non-interactive task command | Project or custom config |
| --- | --- | --- |
| Claude Code | `claude -p "task"` | `~/.claude/agents/`, `<repo>/.claude/agents/`, `<repo>/.claude/skills/` |
| OpenCode | `opencode run "task"` | `~/.config/opencode/agents/`, `<repo>/.opencode/agents/`, `<repo>/.opencode/skills/` |
| Cursor | `agent -p "task"` | `~/.cursor/agents/`, `<repo>/.cursor/agents/` |
| Codex | `codex exec "task"` | `~/.codex/config.toml`, `.codex/config.toml`, `~/.codex/agents/`, `.codex/agents/`, `.agents/skills/`, `AGENTS.md` |
| Hermes | `hermes --oneshot "task"` | `~/.hermes/skills/software-development/`, host-specific Hermes config |

## Install Targets

| Host | Direct skill path |
| --- | --- |
| OpenClaw | `~/.openclaw/skills/agent-repo-router` |
| Claude Code | `~/.claude/skills/agent-repo-router` |
| OpenCode | `~/.config/opencode/skills/agent-repo-router` |
| Codex | `~/.agents/skills/agent-repo-router` |
| Hermes | `~/.hermes/skills/software-development/agent-repo-router` |

Codex also officially supports `codex exec -C /path/to/repo "task"`. AgentRepoRouter documentation still uses `cd /path && ...` examples so the routing pattern stays uniform across CLIs.

## Example

```text
User: "Fix the auth bug in the api project, use the repo's build_and_test skill."

Router:
1. Match repo alias `api` -> `example-backend`
2. Read detected project skills -> `build_and_test`
3. Read detected project agents -> `bugfix`
4. Choose the best native CLI path
5. Execute directly in the target repo
```

## When AgentRepoRouter Is The Right Tool

Use AgentRepoRouter when you want:

- an existing agent host as the entry point
- multiple repos and multiple coding CLIs
- routing that respects project-level skills and agents
- a lighter layer than full agent swarms or kanban orchestrators

Pair AgentRepoRouter with other tools when needed:

- use MCO when you want the same task reviewed by multiple CLIs in parallel
- use agtx or Agent Orchestrator when you want worktree-heavy lifecycle automation
- use metaswarm when you want a much more opinionated SDLC process

## Documentation

- [CLAUDE.md](CLAUDE.md) - Full project context
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) - Current architecture and runtime conventions
- [docs/PRODUCT.md](docs/PRODUCT.md) - Future roadmap, not current implementation
- [docs/advertisement/why-agent-repo-router.md](docs/advertisement/why-agent-repo-router.md) - Recommendation article for potential users
- [docs/plans/migration/plan.md](docs/plans/migration/plan.md) - Migration history and implementation plan
- [legacy/README.md](legacy/README.md) - Archived legacy materials
