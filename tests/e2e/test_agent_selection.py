"""E2E tests for agent selection, cli_priority, skill rules, and fallback"""

import shutil
from pathlib import Path

import pytest
import yaml

from orchai.acp_adapter import ACPAdapter
from orchai.config import Config

TEST_BACKEND = "tests/repos/test-backend"


@pytest.fixture
def test_repo():
    return TEST_BACKEND


@pytest.fixture
def router_config_path(tmp_path):
    config = {
        "fallback": {"enabled": True, "max_retries": 3},
        "cli_priority": ["claude-code", "opencode", "codex"],
    }
    config_file = tmp_path / "router_config.yaml"
    with open(config_file, "w") as f:
        yaml.dump(config, f)
    return str(config_file)


class TestCLICalling:
    """Test basic CLI calling - verify each CLI can be invoked"""

    @pytest.mark.asyncio
    async def test_opencode_basic_call(self, test_repo):
        """Test that opencode can be called"""
        adapter = ACPAdapter()

        result = await adapter.execute_agent(
            agent="opencode",
            repo=test_repo,
            task="what files are in the src directory?",
        )

        assert result["status"] == "completed"
        assert len(result["events"]) > 0
        print(f"\n✓ opencode executed successfully, events: {len(result['events'])}")

    @pytest.mark.asyncio
    async def test_codex_basic_call(self, test_repo):
        """Test that codex can be called"""
        adapter = ACPAdapter()

        result = await adapter.execute_agent(
            agent="codex",
            repo=test_repo,
            task="what files are in the src directory?",
        )

        assert result["status"] == "completed"
        assert len(result["events"]) > 0
        print(f"\n✓ codex executed successfully, events: {len(result['events'])}")


class TestCLIPriorityOrder:
    """Test cli_priority order is respected"""

    def test_default_priority_order(self):
        """Test default cli_priority order is claude-code > opencode > codex"""
        config = Config("config")
        router_config = config.router_config

        cli_priority = router_config.get("cli_priority", [])
        assert cli_priority == ["claude-code", "opencode", "codex"], (
            f"Expected default order ['claude-code', 'opencode', 'codex'], got {cli_priority}"
        )
        print(f"\n✓ Default priority order: {cli_priority}")

    def test_custom_priority_order(self, tmp_path):
        """Test custom cli_priority order can be set"""
        import yaml

        config_content = {
            "fallback": {"enabled": True, "max_retries": 3},
            "cli_priority": ["codex", "opencode", "claude-code"],
        }
        config_file = tmp_path / "router_config.yaml"
        with open(config_file, "w") as f:
            yaml.dump(config_content, f)

        with open(config_file) as f:
            loaded = yaml.safe_load(f)

        cli_priority = loaded.get("cli_priority", [])

        assert cli_priority == ["codex", "opencode", "claude-code"]
        print(f"\n✓ Custom priority order: {cli_priority}")


class TestSkillRules:
    """Test skill prefix rules"""

    def test_claude_has_custom_skill(self):
        """Test that .claude/skills/ exists in test-backend"""
        skills_path = Path(TEST_BACKEND) / ".claude" / "skills"
        assert skills_path.exists(), f"Expected {skills_path} to exist"
        assert skills_path.is_dir()

        skills = list(skills_path.iterdir())
        assert len(skills) > 0, "Expected at least one skill"
        print(f"\n✓ Found skills in .claude/skills/: {[s.name for s in skills]}")

    def test_opencode_no_custom_skill(self):
        """Test that .opencode/skills/ does NOT exist in test-backend"""
        skills_path = Path(TEST_BACKEND) / ".opencode" / "skills"
        assert not skills_path.exists(), f"Expected {skills_path} to NOT exist"
        print("\n✓ .opencode/skills/ does not exist (as expected)")

    def test_detection_logic(self):
        """Test the detection logic matches prompt expectations"""
        repo = Path(TEST_BACKEND)

        claude_agent = repo / ".claude"
        claude_skills = repo / ".claude" / "skills"

        opencode_agent = repo / ".opencode"
        opencode_skills = repo / ".opencode" / "skills"

        codex_agent = repo / ".codex"
        codex_skills = repo / ".codex" / "skills"

        detection = {
            "claude-code": {
                "has_agent": claude_agent.exists(),
                "has_skill": claude_skills.exists(),
                "skills": [s.name for s in claude_skills.iterdir()]
                if claude_skills.exists()
                else [],
            },
            "opencode": {
                "has_agent": opencode_agent.exists(),
                "has_skill": opencode_skills.exists(),
                "skills": [s.name for s in opencode_skills.iterdir()]
                if opencode_skills.exists()
                else [],
            },
            "codex": {
                "has_agent": codex_agent.exists(),
                "has_skill": codex_skills.exists(),
                "skills": [s.name for s in codex_skills.iterdir()]
                if codex_skills.exists()
                else [],
            },
        }

        print(f"\n✓ Detection results: {detection}")

        assert detection["claude-code"]["has_agent"] is True
        assert detection["claude-code"]["has_skill"] is True
        assert "build_and_test" in detection["claude-code"]["skills"]

        assert detection["opencode"]["has_agent"] is True
        assert detection["opencode"]["has_skill"] is False

        assert detection["codex"]["has_agent"] is True
        assert detection["codex"]["has_skill"] is False


class TestFallback:
    """Test fallback when CLI is not available"""

    @pytest.mark.asyncio
    async def test_claude_code_not_available(self, test_repo):
        """Test that claude-code is not available in the system"""
        which_claude = shutil.which("claude-code")
        print(f"\n✓ claude-code path: {which_claude}")
        assert which_claude is None, "claude-code should NOT be installed"

    @pytest.mark.asyncio
    async def test_fallback_to_opencode(self, test_repo):
        """Test fallback from claude-code to opencode"""
        adapter = ACPAdapter()

        result = await adapter.execute_with_fallback(
            repo=test_repo,
            task="list the files in src directory",
            agents=["claude-code", "opencode"],
        )

        assert result["success"] is True
        assert result["meta"]["agent"] == "opencode", (
            f"Expected fallback to opencode, got {result['meta']['agent']}"
        )
        assert result["meta"]["fallback_used"] is True
        print(f"\n✓ Fallback used: claude-code → {result['meta']['agent']}")

    @pytest.mark.asyncio
    async def test_fallback_chain_all_available(self, test_repo):
        """Test fallback chain when first two fail"""
        adapter = ACPAdapter()

        result = await adapter.execute_with_fallback(
            repo=test_repo,
            task="what is in src directory",
            agents=["claude-code", "opencode", "codex"],
        )

        assert result["success"] is True
        assert result["meta"]["agent"] in ["opencode", "codex"]
        assert result["meta"]["fallback_used"] is True
        print(f"\n✓ Fallback chain works: {result['meta']['agent']}")

    @pytest.mark.asyncio
    async def test_all_agents_fail(self, test_repo):
        """Test error when all agents fail"""
        adapter = ACPAdapter()

        with pytest.raises(Exception) as exc_info:
            await adapter.execute_with_fallback(
                repo="/nonexistent/path",
                task="do something",
                agents=["claude-code", "opencode", "codex"],
            )

        assert "failed" in str(exc_info.value).lower()
        print(f"\n✓ All agents failed (expected): {exc_info.value}")


class TestIntegration:
    """Integration tests combining all features"""

    @pytest.mark.asyncio
    async def test_full_flow_with_detection(self, test_repo):
        """Test full flow: detection + priority + fallback"""
        adapter = ACPAdapter()

        result = await adapter.execute_with_fallback(
            repo=test_repo,
            task="list files in src",
            agents=["claude-code", "opencode", "codex"],
        )

        assert result["success"] is True
        print(
            f"\n✓ Full flow executed: agent={result['meta']['agent']}, fallback={result['meta']['fallback_used']}"
        )


if __name__ == "__main__":
    pytest.main([__file__, "-v", "-s"])
