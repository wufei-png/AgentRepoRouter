# OrchAI

Unified personal AI assistant system that orchestrates multiple coding agents using OpenClaw, Temporal, and MCP.

## Features

- **Multi-Agent Orchestration**: Manage Claude Code, Codex, Cursor, OpenCode, and other coding agents
- **Workspace Management**: Work with multiple project directories
- **Temporal Integration**: Durable workflows for long-running tasks
- **MCP Support**: Connect to knowledge bases, git, and other tools via MCP
- **ACP Protocol**: Standard protocol for calling external coding agents

## Installation

```bash
pip install -e .
```

## Configuration

Copy `.env.example` to `.env` and configure:

```bash
cp orchai/.env.example orchai/.env
```

## Usage

### Interactive Mode

```bash
python -m orchai.main --interactive
```

### Run a Workflow

```bash
python -m orchai.main --workflow code_review --params '{"repo_path": "/path/to/repo"}'
```

## Architecture

```
┌─────────────────────────────────────────┐
│           OrchAI Control Plane          │
│                                          │
│  - Workspace Manager                     │
│  - Agent Manager                        │
│  - Workflow Manager                     │
│  - MCP Manager                         │
└─────────────────────────────────────────┘
           │              │
           ▼              ▼
    ┌──────────┐   ┌──────────┐
    │   ACP    │   │   MCP    │
    │  Agents  │   │  Servers │
    └──────────┘   └──────────┘
```

## License

MIT
