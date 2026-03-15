# OrchAI

AI Coding Agent Orchestrator using acpx

## Quick Start

```bash
# Setup with uv
uv venv
source .venv/bin/activate
uv pip install -e .

# Run demo
python3 demo.py

# Initialize
orchai init
```

## Features

✓ **acpx Integration**: Uses acpx for ACP protocol communication
✓ **uv Package Manager**: Fast Python environment management
✓ **Intelligent Routing**: Task analysis and repo matching
✓ **Multi-Agent Support**: claude/codex/opencode via acpx
✓ **Minimal Core**: ~150 lines

## Architecture

```
User → Router → acpx → Agent (claude/codex/opencode)
```

## Example

```bash
# Router decides: test-backend + opencode
npx acpx@latest opencode --cwd tests/repos/test-backend "fix login bug"
```


## Ruff Setup

### Install

```bash
python3.11 -m pip install --upgrade ruff pre-commit
```

### Install git hooks

```bash
pre-commit install
```

### Run lint + format on all files

```bash
pre-commit run --all-files
pre-commit run ruff-check --all-files
pre-commit run ruff-format --all-files
```

This command will run all configured pre-commit hooks on every tracked file.  
With the current `.pre-commit-config.yaml`, it等价于依次执行：

- **`ruff-check` hook**: roughly `ruff check . --fix`  
  - **作用**: 使用 Ruff 对所有 Python 文件做「静态检查 + 自动修复」：  
    - 检查代码风格、常见 bug、复杂度等问题  
    - 能自动修复的问题会直接改写文件（等价于在项目根目录运行 `ruff check . --fix`）
- **`ruff-format` hook**: roughly `ruff format .`  
  - **作用**: 使用 Ruff 的 formatter 统一代码格式（缩进、空行、引号风格等），等价于在项目根目录运行 `ruff format .`

### Update and reinstall pre-commit hooks

```bash
pre-commit autoupdate    # 自动更新所有 rev
pre-commit install
```

### Run Ruff directly (optional)

```bash
ruff check . --fix
ruff format .
```
