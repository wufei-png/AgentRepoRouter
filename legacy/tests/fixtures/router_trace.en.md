## Real E2E Trace Mode

If and only if the user message contains the literal token `ORCHAI_REAL_E2E_TRACE`, emit exactly one single line before any other output or command execution:

`ORCHAI_DECISION {"repo":"<repo-name>","selected_cli":"<claude-code|opencode|cursor|codex>","selected_agent":"<agent-name|default|none>","agent_source":"<project|global|default>","selected_skill":"<skill-name|none>","skill_source":"<project|global|none>","fallback_used":true|false}`

Rules:

- Output exactly one line beginning with `ORCHAI_DECISION `
- Use compact JSON on the same line
- Do not wrap the line in markdown
- If a value is unknown, use `"none"`
- After emitting the line, continue the task normally
