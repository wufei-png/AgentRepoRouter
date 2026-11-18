"""Unit tests for AgentRepoRouter skill source assets."""

import json
import subprocess
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
ROUTER_DIR = PROJECT_ROOT / "skills" / "agent-repo-router"


def test_skill_variants_use_references_repo_mappings():
    expected_guides = {
        ROUTER_DIR / "SKILL.zh.md": "references/guide.zh.md",
        ROUTER_DIR / "SKILL.md": "references/guide.en.md",
    }

    for skill_path, guide_ref in expected_guides.items():
        content = skill_path.read_text()

        assert "references/repo_mappings.json" in content
        assert guide_ref in content
        assert "--cwd" not in content
        assert "use skill <skill-name> to solve the following task" in content
        assert "use agent" in content
        assert "AGENT_REPO_ROUTER_REAL_E2E_TRACE" not in content
        assert "agent-repo-router" in content


def test_router_reference_guides_exist():
    assert (ROUTER_DIR / "references" / "guide.zh.md").exists()
    assert (ROUTER_DIR / "references" / "guide.en.md").exists()


def test_skill_is_manual_only_for_codex():
    skill_content = (ROUTER_DIR / "SKILL.md").read_text()
    metadata_content = (ROUTER_DIR / "agents" / "openai.yaml").read_text()

    assert "disable-model-invocation: true" in skill_content
    assert "allow_implicit_invocation: false" in metadata_content


def test_reference_repo_mappings_matches_current_schema():
    data = json.loads((ROUTER_DIR / "references" / "repo_mappings.json").read_text())

    assert set(data.keys()) == {
        "schemaVersion",
        "installMode",
        "installHosts",
        "executionClis",
        "repos",
    }
    assert data["schemaVersion"] == 2
    assert "language" not in data
    assert data["installMode"] == "global"
    assert data["installHosts"] == [
        "global",
        "openclaw",
        "claude-code",
        "opencode",
        "codex",
        "hermes",
    ]
    assert data["executionClis"] == [
        "claude-code",
        "opencode",
        "cursor",
        "codex",
        "hermes",
    ]
    assert all(
        set(repo.keys()) == {"name", "path", "aliases", "skills", "agents"}
        for repo in data["repos"]
    )
    assert data["repos"][0]["aliases"] == ["backend", "api"]
    assert data["repos"][0]["skills"] == {
        "claude-code": [
            {
                "name": "build_and_test",
                "description": "Run build and tests before finishing changes.",
            }
        ]
    }
    assert data["repos"][0]["agents"] == {
        "claude-code": [
            {
                "name": "bugfix",
                "description": "Fix bugs and regressions with targeted changes.",
            }
        ]
    }
    assert data["repos"][1]["aliases"] == []
    assert data["repos"][1]["skills"] == {}
    assert data["repos"][1]["agents"] == {}


def test_legacy_repo_mappings_file_has_been_removed():
    assert not (ROUTER_DIR / "repo_mappings.json").exists()


def test_repo_mappings_validator_accepts_reference_file():
    result = subprocess.run(
        [
            str(PROJECT_ROOT / "scripts" / "validate_repo_mappings.sh"),
            str(ROUTER_DIR / "references" / "repo_mappings.json"),
        ],
        text=True,
        capture_output=True,
        check=False,
    )

    assert result.returncode == 0, result.stderr
