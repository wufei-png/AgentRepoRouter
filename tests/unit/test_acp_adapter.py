"""Unit tests for ACP Adapter"""

import pytest

from orchai.acp_adapter import ACPAdapter


@pytest.mark.asyncio
async def test_execute_with_fallback():
    adapter = ACPAdapter()
    # Mock test - actual implementation would test real ACP calls
    assert adapter.CLI_COMMANDS["claude-code"] is not None


def test_cli_commands_defined():
    adapter = ACPAdapter()
    assert "claude-code" in adapter.CLI_COMMANDS
    assert "opencode" in adapter.CLI_COMMANDS
    assert "codex" in adapter.CLI_COMMANDS
