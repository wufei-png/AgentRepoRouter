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
    assert (deployed_skill_path(home_dir).parent / "references" / "guide.zh.md").exists()
    assert not (deployed_skill_path(home_dir).parent / "references" / "guide.en.md").exists()
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


def test_existing_router_directory_can_be_deleted_and_overwritten(tmp_path):
    home_dir = tmp_path / "home"
    router_dir = home_dir / ".openclaw" / "skills" / "router"
    fake_bin = make_fake_bin(
        tmp_path,
        {"node", "git", "openclaw", "claude", "opencode", "agent", "codex"},
    )

    (router_dir / "references").mkdir(parents=True)
    (router_dir / "old.txt").write_text("old-router")

    user_input = manual_install_input("1", "1,2", [str(PROJECT_ROOT)]) + "1\n"
    result = run_install(home_dir, user_input, with_fake_path(fake_bin))

    assert result.returncode == 0, result.stdout + result.stderr
    assert not (router_dir / "old.txt").exists()
    assert deployed_skill_path(home_dir).exists()
    assert not (home_dir / ".openclaw" / "skills" / "router_backup_0").exists()


def test_existing_router_directory_can_be_backed_up_with_incrementing_suffix(tmp_path):
    home_dir = tmp_path / "home"
    skills_dir = home_dir / ".openclaw" / "skills"
    router_dir = skills_dir / "router"
    fake_bin = make_fake_bin(
        tmp_path,
        {"node", "git", "openclaw", "claude", "opencode", "agent", "codex"},
    )

    (router_dir / "references").mkdir(parents=True)
    (router_dir / "old.txt").write_text("old-router")
    (skills_dir / "router_backup_0").mkdir(parents=True)

    user_input = manual_install_input("1", "1,2", [str(PROJECT_ROOT)]) + "2\n"
    result = run_install(home_dir, user_input, with_fake_path(fake_bin))

    assert result.returncode == 0, result.stdout + result.stderr
    assert (skills_dir / "router_backup_1").exists()
    assert (skills_dir / "router_backup_1" / "old.txt").read_text() == "old-router"
    assert deployed_skill_path(home_dir).exists()
