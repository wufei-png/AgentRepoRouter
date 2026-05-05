"""Unit tests for Router skill source assets."""

import json
import subprocess
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
ROUTER_DIR = PROJECT_ROOT / "skills" / "router"


def test_skill_variants_use_references_repo_mappings():
    expected_guides = {
        ROUTER_DIR / "SKILL.zh.md": "references/guide.zh.md",
        ROUTER_DIR / "SKILL.en.md": "references/guide.en.md",
    }

    for skill_path, guide_ref in expected_guides.items():
        content = skill_path.read_text()

        assert "references/repo_mappings.json" in content
        assert guide_ref in content
        assert "--cwd" not in content
        assert "use skill <skill-name> to solve the following task" in content
        assert "use agent" in content
        assert "ORCHAI_REAL_E2E_TRACE" not in content


def test_router_reference_guides_exist():
    assert (ROUTER_DIR / "references" / "guide.zh.md").exists()
    assert (ROUTER_DIR / "references" / "guide.en.md").exists()


def test_reference_repo_mappings_matches_current_schema():
    data = json.loads((ROUTER_DIR / "references" / "repo_mappings.json").read_text())

    assert set(data.keys()) == {"schemaVersion", "agents", "repos"}
    assert data["schemaVersion"] == 1
    assert "language" not in data
    assert data["agents"] == ["claude-code", "opencode", "cursor", "codex"]
    assert all(set(repo.keys()) == {"name", "path", "aliases", "skills"} for repo in data["repos"])
    assert data["repos"][0]["aliases"] == ["backend", "api"]
    assert data["repos"][0]["skills"] == {
        "claude-code": [
            {
                "name": "build_and_test",
                "description": "Run build and tests before finishing changes.",
            }
        ]
    }
    assert data["repos"][1]["aliases"] == []
    assert data["repos"][1]["skills"] == {}


def test_legacy_repo_mappings_file_has_been_removed():
    assert not (ROUTER_DIR / "repo_mappings.json").exists()


def test_repo_mappings_validator_accepts_reference_file():
    result = subprocess.run(
        [str(PROJECT_ROOT / "scripts" / "validate_repo_mappings.sh"), str(ROUTER_DIR / "references" / "repo_mappings.json")],
        text=True,
        capture_output=True,
        check=False,
    )

    assert result.returncode == 0, result.stderr
