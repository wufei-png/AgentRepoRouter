# Test Results

## Latest Verification

Date: `2026-03-25`

Command:

```bash
PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 uv run --with pytest pytest -q
```

Result:

```text
15 passed in 2.85s
```

## Covered Areas

- `install.sh` rejects unsupported environments
- `install.sh` deploys `SKILL.md` and `references/repo_mappings.json` into `~/.openclaw/skills/router/`
- `repo_mappings.json` carries `schemaVersion` and passes schema validation
- Manual input and auto scan both generate the expected config
- Duplicate project names are filtered by repo name
- Relative manual paths are rejected
- Language selection deploys exactly one `SKILL.md`
- Test repos contain the expected custom agent / skill fixtures
