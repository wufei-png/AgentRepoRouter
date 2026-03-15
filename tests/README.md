# OrchAI Tests

## Prerequisites

1. **Initialize git repos** (acpx requires git):
```bash
cd tests/repos/test-backend && git init && git add -A && git commit -m "init"
cd tests/repos/test-docs && git init && git add -A && git commit -m "init"
```

2. **Create acpx sessions**:
```bash
cd tests/repos/test-backend && npx acpx@latest opencode sessions new
cd tests/repos/test-docs && npx acpx@latest codex sessions new
```

## Manual Shell Tests

### Test 1: Backend Q&A
```bash
cd tests/repos/test-backend
npx acpx@latest opencode "介绍这个项目的功能"
```
**Expected**: Agent describes the authentication module

### Test 2: Docs Q&A
```bash
cd tests/repos/test-docs
npx acpx@latest codex "what is the deployment process?"
```
**Expected**: Agent reads docs/deployment.md and explains

### Test 3: Bugfix
```bash
cd tests/repos/test-backend
npx acpx@latest opencode "fix the bug in src/auth.py where login always returns True"
```
**Expected**: Agent fixes the bug

## Python Tests (unit, integration, e2e)

From project root with venv activated (or use `uv run`):

```bash
cd /home/wufei/github.com/wufei-png/OrchAI
uv venv && source .venv/bin/activate
uv pip install -e .
pytest -v
```

**Expected**: All 13 tests pass (unit, integration, e2e). `pytest` uses `testpaths` in `pyproject.toml` (unit, integration, e2e only; `tests/repos` fixture code is excluded). If `pytest` is not in PATH, run `uv run pytest -v`.
