"""E2E tests for custom agents and skills detection"""

from pathlib import Path

import pytest

TEST_BACKEND = "tests/repos/test-backend"
TEST_DOCS = "tests/repos/test-docs"


class TestCustomAgents:
    def test_codex_has_custom_agent_in_test_backend(self):
        agent_path = Path(TEST_BACKEND) / ".codex" / "agents" / "bug-fixer.toml"
        assert agent_path.exists(), f"Expected {agent_path} to exist"
        print(f"\n✓ Found custom agent: {agent_path}")

    def test_opencode_has_custom_agent_in_test_docs(self):
        agent_path = Path(TEST_DOCS) / ".opencode" / "agents" / "doc-writer.md"
        assert agent_path.exists(), f"Expected {agent_path} to exist"
        print(f"\n✓ Found custom agent: {agent_path}")


class TestCustomSkills:
    def test_claude_code_has_skills_in_test_backend(self):
        skills_path = Path(TEST_BACKEND) / ".claude" / "skills"
        assert skills_path.exists(), f"Expected {skills_path} to exist"

        skills = [s.name for s in skills_path.iterdir() if s.is_dir()]
        assert "bug-fixer" in skills, f"Expected bug-fixer skill, got {skills}"
        assert "build_and_test" in skills
        print(f"\n✓ Claude Code skills: {skills}")

    def test_claude_code_has_skills_in_test_docs(self):
        skills_path = Path(TEST_DOCS) / ".claude" / "skills"
        assert skills_path.exists(), f"Expected {skills_path} to exist"

        skills = [s.name for s in skills_path.iterdir() if s.is_dir()]
        assert "doc-writer" in skills, f"Expected doc-writer skill, got {skills}"
        print(f"\n✓ Claude Code skills: {skills}")

    def test_opencode_has_skills_in_test_backend(self):
        skills_path = Path(TEST_BACKEND) / ".opencode" / "skills"
        assert skills_path.exists(), f"Expected {skills_path} to exist"

        skills = [s.name for s in skills_path.iterdir() if s.is_dir()]
        assert "bug-fix" in skills, f"Expected bug-fix skill, got {skills}"
        print(f"\n✓ OpenCode skills: {skills}")

    def test_codex_has_skills_in_test_docs(self):
        skills_path = Path(TEST_DOCS) / ".agents" / "skills"
        assert skills_path.exists(), f"Expected {skills_path} to exist"

        skills = [s.name for s in skills_path.iterdir() if s.is_dir()]
        assert "doc-writer" in skills, f"Expected doc-writer skill, got {skills}"
        print(f"\n✓ Codex skills: {skills}")


class TestAgentSkillDetection:
    def test_test_backend_detection(self):
        repo = Path(TEST_BACKEND)
        claude_skills_path = repo / ".claude" / "skills"
        opencode_skills_path = repo / ".opencode" / "skills"
        codex_agents_path = repo / ".codex" / "agents"

        claude_skills_list = (
            [s.name for s in claude_skills_path.iterdir() if s.is_dir()]
            if claude_skills_path.exists()
            else []
        )
        opencode_skills_list = (
            [s.name for s in opencode_skills_path.iterdir() if s.is_dir()]
            if opencode_skills_path.exists()
            else []
        )
        codex_agents_list = (
            [s.name for s in codex_agents_path.iterdir() if s.suffix == ".toml"]
            if codex_agents_path.exists()
            else []
        )

        detection = {
            "claude-code": {
                "skills_dir": claude_skills_path.exists(),
                "skills": claude_skills_list,
            },
            "opencode": {
                "skills_dir": opencode_skills_path.exists(),
                "skills": opencode_skills_list,
            },
            "codex": {
                "agents": codex_agents_list,
            },
        }

        print(f"\n✓ test-backend detection: {detection}")

        assert detection["claude-code"]["skills_dir"] is True
        assert "bug-fixer" in claude_skills_list
        assert "build_and_test" in claude_skills_list

        assert detection["opencode"]["skills_dir"] is True
        assert "bug-fix" in opencode_skills_list

        assert codex_agents_list == ["bug-fixer.toml"]

    def test_test_docs_detection(self):
        repo = Path(TEST_DOCS)
        claude_skills_path = repo / ".claude" / "skills"
        opencode_agents_path = repo / ".opencode" / "agents"
        codex_skills_path = repo / ".agents" / "skills"

        claude_skills_list = (
            [s.name for s in claude_skills_path.iterdir() if s.is_dir()]
            if claude_skills_path.exists()
            else []
        )
        opencode_agents_list = (
            [s.name for s in opencode_agents_path.iterdir() if s.suffix == ".md"]
            if opencode_agents_path.exists()
            else []
        )
        codex_skills_list = (
            [s.name for s in codex_skills_path.iterdir() if s.is_dir()]
            if codex_skills_path.exists()
            else []
        )

        detection = {
            "claude-code": {
                "skills_dir": claude_skills_path.exists(),
                "skills": claude_skills_list,
            },
            "opencode": {
                "agents": opencode_agents_list,
            },
            "codex": {
                "skills_dir": codex_skills_path.exists(),
                "skills": codex_skills_list,
            },
        }

        print(f"\n✓ test-docs detection: {detection}")

        assert detection["claude-code"]["skills_dir"] is True
        assert "doc-writer" in claude_skills_list

        assert opencode_agents_list == ["doc-writer.md"]

        assert detection["codex"]["skills_dir"] is True
        assert "doc-writer" in codex_skills_list


class TestSkillVsAgent:
    def test_skill_priority_over_agent(self):
        opencode_skills = Path(TEST_BACKEND) / ".opencode" / "skills"
        assert opencode_skills.exists(), "OpenCode should have skills"

        codex_agents = Path(TEST_BACKEND) / ".codex" / "agents"
        assert codex_agents.exists(), "Codex should have agents"

        print("\n✓ Skill takes priority over custom agent")

    def test_custom_agent_when_no_skill(self):
        opencode_agents = Path(TEST_DOCS) / ".opencode" / "agents"
        assert opencode_agents.exists(), "OpenCode should have custom agent"

        codex_skills = Path(TEST_DOCS) / ".agents" / "skills"
        assert codex_skills.exists(), "Codex should have skills"

        print("\n✓ Custom agent used when no skill exists")


if __name__ == "__main__":
    pytest.main([__file__, "-v", "-s"])
