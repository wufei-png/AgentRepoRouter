#!/usr/bin/env bash
set -euo pipefail

if [ "${ORCHAI_REAL_E2E:-0}" != "1" ]; then
    echo "Set ORCHAI_REAL_E2E=1 to run live OpenClaw end-to-end tests." >&2
    exit 1
fi

if [ -z "${ORCHAI_REAL_E2E_AGENT:-}" ] || [ -z "${ORCHAI_REAL_E2E_AGENT_WORKSPACE:-}" ]; then
    echo "ORCHAI_REAL_E2E_AGENT and ORCHAI_REAL_E2E_AGENT_WORKSPACE are required." >&2
    exit 1
fi

echo "Checking OpenClaw health..."
openclaw health --json >/dev/null

echo "Running real OpenClaw e2e tests..."
PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 uv run --with pytest pytest tests/real_e2e -m real_e2e -q "$@"
