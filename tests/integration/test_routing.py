"""Integration test for routing flow"""

from pathlib import Path

from orchai.router import Router


# TODO: Fix hardcoded path - 修复硬编码路径的问题 (Low #19)
# Use relative path from test file location or environment variable
def get_mappings_path() -> Path:
    """Get mappings file path relative to test file"""
    # Get the test file's directory
    test_dir = Path(__file__).parent
    # Navigate to project root (tests/integration -> project root)
    project_root = test_dir.parent.parent
    return project_root / "skills" / "router" / "repo_mappings.json"


def test_backend_routing():
    """Test routing to backend project"""
    router = Router(str(get_mappings_path()))
    result = router.route("fix login bug in test-backend")

    assert result["found"]
    assert result["repo"] == "test-backend"
    assert result["agent"] == "opencode"
    assert result["taskType"] == "bugfix"


def test_docs_routing():
    """Test routing to docs project"""
    router = Router(str(get_mappings_path()))
    result = router.route("update deployment documentation")

    assert result["found"]
    assert result["repo"] == "test-docs"


def test_ambiguous_routing():
    """Test ambiguous task routing"""
    router = Router(str(get_mappings_path()))
    result = router.route("update something")

    assert not result["found"]
    assert "candidates" in result
