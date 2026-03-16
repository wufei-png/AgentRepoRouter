"""Unit tests for Router"""

import json

import pytest

from orchai.router import Router, _classify_task


@pytest.fixture
def router(tmp_path):
    mappings_file = tmp_path / "mappings.json"
    mappings = {
        "repos": [
            {
                "name": "test-backend",
                "keywords": ["auth", "login", "backend"],
                "agents": {"primary": "opencode", "fallback": ["claude-code"]},
            },
            {
                "name": "test-docs",
                "keywords": ["docs", "documentation"],
                "agents": {"primary": "codex", "fallback": ["claude-code"]},
            },
        ]
    }
    with open(mappings_file, "w") as f:
        json.dump(mappings, f)
    return Router(str(mappings_file))


def test_route_clear_match(router):
    result = router.route("fix login bug in backend")
    assert result["found"]
    assert result["repo"] == "test-backend"
    assert result["agent"] == "opencode"


def test_route_ambiguous(router):
    result = router.route("update something")
    assert not result["found"]
    assert len(result["candidates"]) >= 0


def test_classify_task():
    assert _classify_task("add new feature") == "feature"
    assert _classify_task("fix bug") == "bugfix"
    assert _classify_task("refactor code") == "refactor"
