"""Integration tests for install.sh deployment."""

from testsupport import (
    PROJECT_ROOT,
    deployed_config_path,
    deployed_skill_path,
    load_deployed_config,
    make_fake_bin,
    manual_install_input,
    run_install,
    with_fake_path,
)


def test_manual_install_deploys_skill_and_config_into_router_directory(tmp_path):
    home_dir = tmp_path / "home"
    fake_bin = make_fake_bin(
        tmp_path,
        {"node", "git", "openclaw", "claude", "opencode", "agent", "codex"},
    )

    result = run_install(
        home_dir,
        manual_install_input("1", "1,2", [str(PROJECT_ROOT)]),
        with_fake_path(fake_bin),
    )

    assert result.returncode == 0, result.stdout + result.stderr
    assert deployed_skill_path(home_dir).exists()
    assert deployed_config_path(home_dir).exists()
    assert not (home_dir / ".orchai" / "repo_mappings.json").exists()

    deployed_config = load_deployed_config(home_dir)
    assert deployed_config == {
        "schemaVersion": 1,
        "agents": ["claude-code", "opencode"],
        "repos": [
            {
                "name": "OrchAI",
                "path": str(PROJECT_ROOT),
                "type": "backend",
            }
        ],
    }

    assert "读取 `references/repo_mappings.json`" in deployed_skill_path(home_dir).read_text()
