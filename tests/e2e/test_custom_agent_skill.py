"""E2E tests for custom agents and skills fixtures."""

from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
TEST_REPOS = PROJECT_ROOT / "tests" / "repos"


def test_backend_repo_contains_claude_skill_and_agent():
    backend_repo = TEST_REPOS / "test-backend"

    assert (backend_repo / ".claude" / "agents" / "bugfix.md").exists()
    assert (backend_repo / ".claude" / "skills" / "build_and_test" / "SKILL.md").exists()


def test_docs_repo_contains_opencode_skill_and_agent():
    docs_repo = TEST_REPOS / "test-docs"

    assert (docs_repo / ".opencode" / "agents" / "docs_writer.md").exists()
    assert (docs_repo / ".opencode" / "skills" / "doc_writer" / "SKILL.md").exists()


def test_subagents_repo_contains_cross_cli_agent_examples():
    subagents_repo = TEST_REPOS / "test-subagents"

    claude_agents = sorted(
        path.name for path in (subagents_repo / ".claude" / "agents").glob("*.md")
    )
    cursor_agents = sorted(
        path.name for path in (subagents_repo / ".cursor" / "agents").glob("*.md")
    )
    opencode_agents = sorted(
        path.name for path in (subagents_repo / ".opencode" / "agents").glob("*.md")
    )

    assert claude_agents == ["bugfix.md", "docs.md", "qa.md"]
    assert cursor_agents == ["security.md"]
    assert opencode_agents == ["reviewer.md"]
