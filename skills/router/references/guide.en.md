# Router Reference

This reference document holds the longer Router conventions. The runtime-facing rules stay in `../SKILL.en.md`.

## CLI Details

### General

- Use `cd /path && ...` as the uniform working-directory pattern.
- Do not use `--cwd`.
- Only consult this reference when the main skill does not already provide enough guidance.

### Claude Code

- Base command: `claude -p "task"`
- Custom agent: `claude --agent <name> "task"`
- Project agents: `<repo>/.claude/agents/`
- Project skills: `<repo>/.claude/skills/`
- Global agents: `~/.claude/agents/`

### OpenCode

- Base command: `opencode run "task"`
- Custom agents must be invoked through the prompt, not CLI flags.
- Recommended prompt form: `use agent <name> to do: <task>`
- Project agents: `<repo>/.opencode/agents/`
- Project skills: `<repo>/.opencode/skills/`
- Global agents: `~/.config/opencode/agents/`

### Cursor

- The Cursor CLI binary is `agent`, not `cursor agent`.
- Base command: `agent -p "task"`
- Custom agents must be invoked through the prompt.
- Project agents: `<repo>/.cursor/agents/`
- Global agents: `~/.cursor/agents/`

### Codex

- Base command: `codex exec "task"`
- Codex also officially supports `codex exec -C /path/to/repo "task"`, but Router docs use `cd /path && ...` for one consistent pattern.
- Global config: `~/.codex/config.toml`
- Project config: `<repo>/.codex/config.toml`
- Global custom agents: `~/.codex/agents/*.toml`
- Project custom agents: `<repo>/.codex/agents/*.toml`
- Global skills: `$HOME/.agents/skills/`
- Project skills: `<repo>/.agents/skills/`
- Global instructions: `~/.codex/AGENTS.md`
- Project instructions: `AGENTS.md`
- Additional skills can also be declared via `skills.config` paths in `config.toml`
- The current official convention is not `.codex/skills/`

## Routing Details

### Project-level first

- Check custom project skills and agents inside the target repo before looking anywhere global.
- If a project-level skill and agent both match, keep the skill first, then decide whether the agent should also be attached.

### Conservative global matching

- Use a global skill or agent only when the name is highly specific, the responsibility is strongly aligned, or the user explicitly names it.
- Do not inject global helpers on weak similarity.

### Fallback

- If nothing matches reliably, fall back using the `agents` order in `repo_mappings.json`.
- During fallback, do not attach weakly matched skills by default.

## Common Task Categories

- `bugfix`: fix bugs, regressions, or errors
- `feature`: add or implement new behavior
- `refactor`: restructure or clean up code
- `docs`: write or update documentation
- `qa`: answer questions or explain behavior
- `review`: review, inspect, or audit changes
