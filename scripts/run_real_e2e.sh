#!/usr/bin/env bash
set -euo pipefail

env_value() {
    local primary_name="$1"
    local legacy_name="$2"
    local primary_value="${!primary_name-}"
    if [ -n "$primary_value" ]; then
        printf '%s' "$primary_value"
        return 0
    fi
    printf '%s' "${!legacy_name-}"
}

REAL_E2E_ENABLED="$(env_value "CLAWROUTER_REAL_E2E" "ORCHAI_REAL_E2E")"
REAL_E2E_AGENT="$(env_value "CLAWROUTER_REAL_E2E_AGENT" "ORCHAI_REAL_E2E_AGENT")"
REAL_E2E_AGENT_WORKSPACE="$(env_value "CLAWROUTER_REAL_E2E_AGENT_WORKSPACE" "ORCHAI_REAL_E2E_AGENT_WORKSPACE")"

if [ "${REAL_E2E_ENABLED:-0}" != "1" ]; then
    echo "Set CLAWROUTER_REAL_E2E=1 to run live OpenClaw end-to-end tests." >&2
    echo "Legacy ORCHAI_REAL_E2E is still accepted during the transition." >&2
    exit 1
fi

if [ -z "${REAL_E2E_AGENT:-}" ] || [ -z "${REAL_E2E_AGENT_WORKSPACE:-}" ]; then
    echo "CLAWROUTER_REAL_E2E_AGENT and CLAWROUTER_REAL_E2E_AGENT_WORKSPACE are required." >&2
    echo "Legacy ORCHAI_REAL_E2E_AGENT and ORCHAI_REAL_E2E_AGENT_WORKSPACE are still accepted." >&2
    exit 1
fi

echo "Checking OpenClaw health..."
openclaw health --json >/dev/null

echo "Running real OpenClaw e2e tests..."
PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 uv run --with pytest pytest tests/real_e2e -m real_e2e -q "$@"
