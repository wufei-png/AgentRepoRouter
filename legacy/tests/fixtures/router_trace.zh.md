## Real E2E Trace Mode

当且仅当用户消息中包含字面量 `ORCHAI_REAL_E2E_TRACE` 时，在任何其他输出或命令执行之前，先输出一行：

`ORCHAI_DECISION {"repo":"<repo-name>","selected_cli":"<claude-code|opencode|cursor|codex>","selected_agent":"<agent-name|default|none>","agent_source":"<project|global|default>","selected_skill":"<skill-name|none>","skill_source":"<project|global|none>","fallback_used":true|false}`

规则：

- 只能输出一行，并且必须以 `ORCHAI_DECISION ` 开头
- JSON 必须紧凑并放在同一行
- 不要用 markdown 包裹
- 如果某个值未知，使用 `"none"`
- 输出这一行后，再继续正常执行任务
