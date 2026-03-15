# Router Skill

Routes user tasks to appropriate repos and agents using OpenClaw's built-in LLM.

## Usage

When a user sends a task, use this skill to determine which repo and agent to use.

## Repos Configuration

Load repos from:
- `config/projects.yaml` - project list
- `skills/router/repo_mappings.json` - keyword mappings

## Prompt

Analyze the user's task and determine the appropriate repo and agent.

### Available Repos

```
{{repos}}
```

Replace `{{repos}}` with the actual repos list from the config files.

### Task Analysis

1. Analyze the user task
2. Match against repo keywords and descriptions
3. Classify task type:
   - **feature**: adding new functionality (add, implement, create, new)
   - **bugfix**: fixing bugs (fix, bug, error, issue)
   - **refactor**: improving code (refactor, clean, improve)
   - **docs**: documentation (doc, readme, guide)
   - **qa**: questions, code review

4. Select agent based on task type:
   - feature → claude-code
   - bugfix → opencode
   - refactor → claude-code
   - docs → codex
   - qa → codex

## Output

Return JSON:

```json
{
  "found": true,
  "repo": "repo-name",
  "agent": "claude-code|opencode|codex",
  "taskType": "feature|bugfix|refactor|docs|qa",
  "confidence": 0.0-1.0,
  "reasoning": "brief explanation"
}
```

Or if ambiguous:

```json
{
  "found": false,
  "candidates": ["repo1", "repo2"],
  "reason": "explanation"
}
```

## Execution

After routing decision, execute the task using acpx:

```bash
npx acpx@latest --cwd tests/repos/{repo} {agent} "{task}"
```
