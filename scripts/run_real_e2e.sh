#!/usr/bin/env bash
set -euo pipefail

REAL_E2E_ENABLED="${AGENT_REPO_ROUTER_REAL_E2E:-0}"
REAL_E2E_AGENT="${AGENT_REPO_ROUTER_REAL_E2E_AGENT:-}"
REAL_E2E_AGENT_WORKSPACE="${AGENT_REPO_ROUTER_REAL_E2E_AGENT_WORKSPACE:-}"

if [ "${REAL_E2E_ENABLED:-0}" != "1" ]; then
    echo "Set AGENT_REPO_ROUTER_REAL_E2E=1 to run live OpenClaw end-to-end tests." >&2
    exit 1
fi

if [ -z "${REAL_E2E_AGENT:-}" ] || [ -z "${REAL_E2E_AGENT_WORKSPACE:-}" ]; then
    echo "AGENT_REPO_ROUTER_REAL_E2E_AGENT and AGENT_REPO_ROUTER_REAL_E2E_AGENT_WORKSPACE are required." >&2
    exit 1
fi

echo "Checking OpenClaw health..."
openclaw health --json >/dev/null

echo "Running real OpenClaw e2e tests..."
PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 uv run --with pytest pytest tests/real_e2e -m real_e2e -q "$@"
