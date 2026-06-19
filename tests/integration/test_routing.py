"""Integration tests for install.sh deployment."""

from testsupport import (
    PROJECT_ROOT,
    deployed_config_path,
    deployed_host_path,
    deployed_host_skill_path,
    deployed_skill_path,
    load_deployed_config,
    load_host_deployed_config,
    make_fake_bin,
    manual_install_input,
    run_install,
    with_fake_path,
)


def test_default_global_install_creates_canonical_skill_and_host_symlinks(tmp_path):
    home_dir = tmp_path / "home"
    fake_bin = make_fake_bin(
        tmp_path,
        {"node", "git", "openclaw", "claude", "opencode", "agent", "codex", "hermes"},
    )

    result = run_install(
        home_dir,
        manual_install_input("1", "1,2,4", [str(PROJECT_ROOT)], install_mode=""),
        with_fake_path(fake_bin),
    )

    assert result.returncode == 0, result.stdout + result.stderr
    assert deployed_skill_path(home_dir).exists()
    assert deployed_config_path(home_dir).exists()
    assert (deployed_skill_path(home_dir).parent / "references" / "guide.zh.md").exists()
    assert not (deployed_skill_path(home_dir).parent / "references" / "guide.en.md").exists()

    for host in ["openclaw", "claude-code", "opencode", "hermes"]:
        host_path = deployed_host_path(home_dir, host)
        assert host_path.is_symlink()
        assert host_path.resolve() == deployed_skill_path(home_dir).parent.resolve()

    deployed_config = load_deployed_config(home_dir)
    assert deployed_config == {
        "schemaVersion": 2,
        "installMode": "global",
        "installHosts": ["global", "openclaw", "claude-code", "opencode", "codex", "hermes"],
        "executionClis": ["claude-code", "opencode", "codex"],
        "repos": [
            {
                "name": PROJECT_ROOT.name,
                "path": str(PROJECT_ROOT),
                "aliases": [],
                "skills": {},
                "agents": {},
            }
        ],
    }

    assert "读取 `references/repo_mappings.json`" in deployed_skill_path(home_dir).read_text()


def test_single_host_install_writes_directly_without_global_source(tmp_path):
    home_dir = tmp_path / "home"
    fake_bin = make_fake_bin(tmp_path, {"node", "git", "openclaw", "claude"})

    result = run_install(
        home_dir,
        manual_install_input(
            "2",
            "1",
            [str(PROJECT_ROOT)],
            install_mode="2",
            install_hosts="1",
        ),
        with_fake_path(fake_bin),
    )

    openclaw_skill = deployed_host_skill_path(home_dir, "openclaw")

    assert result.returncode == 0, result.stdout + result.stderr
    assert openclaw_skill.exists()
    assert not deployed_skill_path(home_dir).exists()
    assert not deployed_host_path(home_dir, "openclaw").is_symlink()
    assert "Route coding tasks to the right repo and CLI" in openclaw_skill.read_text()
    assert load_host_deployed_config(home_dir, "openclaw")["installMode"] == "single"


def test_codex_single_host_uses_agents_skills_not_codex_skills(tmp_path):
    home_dir = tmp_path / "home"
    fake_bin = make_fake_bin(tmp_path, {"node", "git", "codex"})

    result = run_install(
        home_dir,
        manual_install_input(
            "1",
            "4",
            [str(PROJECT_ROOT)],
            install_mode="2",
            install_hosts="4",
        ),
        with_fake_path(fake_bin),
    )

    codex_skill = deployed_host_skill_path(home_dir, "codex")
    legacy_codex_skill = home_dir / ".codex" / "skills" / "agent-repo-router"

    assert result.returncode == 0, result.stdout + result.stderr
    assert codex_skill.exists()
    assert not codex_skill.parent.is_symlink()
    assert not legacy_codex_skill.exists()
    assert "Codex loads skills from ~/.agents/skills" in result.stdout
    assert "no ~/.codex/skills symlink is created" in result.stdout
    assert load_host_deployed_config(home_dir, "codex")["installMode"] == "single"
    assert load_host_deployed_config(home_dir, "codex")["installHosts"] == ["codex"]


def test_custom_multi_host_install_uses_global_source_and_selected_symlinks(tmp_path):
    home_dir = tmp_path / "home"
    fake_bin = make_fake_bin(tmp_path, {"node", "git", "claude", "opencode"})

    result = run_install(
        home_dir,
        manual_install_input(
            "1",
            "1,2",
            [str(PROJECT_ROOT)],
            install_mode="3",
            install_hosts="2,3",
        ),
        with_fake_path(fake_bin),
    )

    assert result.returncode == 0, result.stdout + result.stderr
    assert deployed_skill_path(home_dir).exists()
    assert deployed_host_path(home_dir, "claude-code").is_symlink()
    assert deployed_host_path(home_dir, "opencode").is_symlink()
    assert not deployed_host_path(home_dir, "openclaw").exists()
    assert load_deployed_config(home_dir)["installMode"] == "custom"
    assert load_deployed_config(home_dir)["installHosts"] == ["claude-code", "opencode"]


def test_custom_all_detected_toggles_every_detected_host(tmp_path):
    home_dir = tmp_path / "home"
    fake_bin = make_fake_bin(
        tmp_path,
        {"node", "git", "openclaw", "claude", "opencode", "codex", "hermes"},
    )

    result = run_install(
        home_dir,
        manual_install_input(
            "1",
            "1,2,4,5",
            [str(PROJECT_ROOT)],
            install_mode="3",
            install_hosts="0",
        ),
        with_fake_path(fake_bin),
    )

    assert result.returncode == 0, result.stdout + result.stderr
    assert load_deployed_config(home_dir)["installHosts"] == [
        "openclaw",
        "claude-code",
        "opencode",
        "codex",
        "hermes",
    ]
    assert deployed_skill_path(home_dir).exists()

    for host in ["openclaw", "claude-code", "opencode", "hermes"]:
        host_path = deployed_host_path(home_dir, host)
        assert host_path.is_symlink()
        assert host_path.resolve() == deployed_skill_path(home_dir).parent.resolve()


def test_existing_real_host_directory_can_be_backed_up_before_symlink(tmp_path):
    home_dir = tmp_path / "home"
    openclaw_dir = deployed_host_path(home_dir, "openclaw")
    fake_bin = make_fake_bin(tmp_path, {"node", "git", "openclaw", "claude"})

    openclaw_dir.mkdir(parents=True)
    (openclaw_dir / "old.txt").write_text("old-router")

    result = run_install(
        home_dir,
        manual_install_input("1", "1", [str(PROJECT_ROOT)], install_mode="1") + "2\n",
        with_fake_path(fake_bin),
    )

    backup_dir = openclaw_dir.with_name("agent-repo-router_backup_0")

    assert result.returncode == 0, result.stdout + result.stderr
    assert backup_dir.exists()
    assert (backup_dir / "old.txt").read_text() == "old-router"
    assert openclaw_dir.is_symlink()
