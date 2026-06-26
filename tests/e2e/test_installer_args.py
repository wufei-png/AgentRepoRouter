"""End-to-end tests for non-interactive installer arguments."""

from pathlib import Path

from testsupport import (
    deployed_config_path,
    deployed_host_path,
    deployed_skill_path,
    load_deployed_config,
    make_fake_bin,
    manual_install_input,
    run_install_args,
    run_install,
    with_fake_path,
)


def make_repo(path: Path, *, git_file: bool = False) -> Path:
    path.mkdir(parents=True, exist_ok=True)
    if git_file:
        (path / ".git").write_text("gitdir: /tmp/example.git\n")
    else:
        (path / ".git").mkdir(exist_ok=True)
    return path


def base_args(repo: Path) -> list[str]:
    return [
        "--yes",
        "--language",
        "en",
        "--repo",
        str(repo),
        "--hosts",
        "codex",
        "--execution-clis",
        "codex",
        "--existing",
        "overwrite",
    ]


def test_yes_repo_install_generates_schema_v2_config(tmp_path):
    home_dir = tmp_path / "home"
    repo = make_repo(tmp_path / "demo-repo")
    fake_bin = make_fake_bin(tmp_path, {"node", "git", "codex"})

    result = run_install_args(home_dir, base_args(repo), with_fake_path(fake_bin))

    assert result.returncode == 0, result.stdout + result.stderr
    config = load_deployed_config(home_dir)
    assert config["schemaVersion"] == 2
    assert config["installMode"] == "single"
    assert config["installHosts"] == ["codex"]
    assert config["executionClis"] == ["codex"]
    assert config["repos"][0]["path"] == str(repo)


def test_auto_scan_respects_explicit_scan_depth(tmp_path):
    home_dir = tmp_path / "home"
    scan_root = tmp_path / "scan-root"
    repo = make_repo(scan_root / "team" / "demo-repo")
    fake_bin = make_fake_bin(tmp_path, {"node", "git", "codex"})

    result = run_install_args(
        home_dir,
        [
            "--yes",
            "--auto-scan",
            "--scan-root",
            str(scan_root),
            "--scan-depth",
            "3",
            "--hosts",
            "codex",
            "--execution-clis",
            "codex",
            "--existing",
            "overwrite",
        ],
        with_fake_path(fake_bin),
    )

    assert result.returncode == 0, result.stdout + result.stderr
    assert load_deployed_config(home_dir)["repos"][0]["path"] == str(repo)


def test_auto_scan_default_depth_is_five(tmp_path):
    home_dir = tmp_path / "home"
    scan_root = tmp_path / "scan-root"
    shallow_repo = make_repo(scan_root / "a" / "b" / "c" / "repo-in-depth-five")
    make_repo(scan_root / "a" / "b" / "c" / "d" / "repo-beyond-depth-five")
    fake_bin = make_fake_bin(tmp_path, {"node", "git", "codex"})

    result = run_install_args(
        home_dir,
        [
            "--yes",
            "--auto-scan",
            "--scan-root",
            str(scan_root),
            "--hosts",
            "codex",
            "--execution-clis",
            "codex",
            "--existing",
            "overwrite",
        ],
        with_fake_path(fake_bin),
    )

    assert result.returncode == 0, result.stdout + result.stderr
    assert "max depth: 5" in result.stdout
    assert [repo["path"] for repo in load_deployed_config(home_dir)["repos"]] == [str(shallow_repo)]


def test_scan_depth_environment_overrides_default(tmp_path):
    home_dir = tmp_path / "home"
    scan_root = tmp_path / "scan-root"
    shallow_repo = make_repo(scan_root / "shallow")
    make_repo(scan_root / "team" / "deep")
    fake_bin = make_fake_bin(tmp_path, {"node", "git", "codex"})
    env = with_fake_path(fake_bin)
    env["AGENT_REPO_ROUTER_SCAN_MAX_DEPTH"] = "2"

    result = run_install_args(
        home_dir,
        [
            "--yes",
            "--auto-scan",
            "--scan-root",
            str(scan_root),
            "--hosts",
            "codex",
            "--execution-clis",
            "codex",
            "--existing",
            "overwrite",
        ],
        env,
    )

    assert result.returncode == 0, result.stdout + result.stderr
    assert "max depth: 2" in result.stdout
    assert [repo["path"] for repo in load_deployed_config(home_dir)["repos"]] == [str(shallow_repo)]


def test_repo_arg_inside_git_repo_normalizes_to_repo_root(tmp_path):
    home_dir = tmp_path / "home"
    repo = make_repo(tmp_path / "demo-repo")
    nested = repo / "src" / "nested"
    nested.mkdir(parents=True)
    fake_bin = make_fake_bin(tmp_path, {"node", "git", "codex"})

    result = run_install_args(home_dir, base_args(nested), with_fake_path(fake_bin))

    assert result.returncode == 0, result.stdout + result.stderr
    assert load_deployed_config(home_dir)["repos"][0]["path"] == str(repo)


def test_repo_arg_prefix_scans_for_git_directories_and_files(tmp_path):
    home_dir = tmp_path / "home"
    prefix = tmp_path / "prefix"
    repo_a = make_repo(prefix / "repo-a")
    repo_b = make_repo(prefix / "repo-b", git_file=True)
    fake_bin = make_fake_bin(tmp_path, {"node", "git", "codex"})

    result = run_install_args(home_dir, base_args(prefix), with_fake_path(fake_bin))

    assert result.returncode == 0, result.stdout + result.stderr
    assert {repo["path"] for repo in load_deployed_config(home_dir)["repos"]} == {
        str(repo_a),
        str(repo_b),
    }


def test_hosts_all_selects_detected_hosts(tmp_path):
    home_dir = tmp_path / "home"
    repo = make_repo(tmp_path / "demo-repo")
    fake_bin = make_fake_bin(tmp_path, {"node", "git", "claude", "opencode", "codex"})

    result = run_install_args(
        home_dir,
        [
            "--yes",
            "--repo",
            str(repo),
            "--hosts",
            "all",
            "--execution-clis",
            "codex",
            "--existing",
            "overwrite",
        ],
        with_fake_path(fake_bin),
    )

    assert result.returncode == 0, result.stdout + result.stderr
    assert load_deployed_config(home_dir)["installHosts"] == [
        "claude-code",
        "opencode",
        "codex",
    ]


def test_hosts_all_falls_back_to_codex_when_only_cursor_is_detected(tmp_path):
    home_dir = tmp_path / "home"
    repo = make_repo(tmp_path / "demo-repo")
    fake_bin = make_fake_bin(tmp_path, {"node", "git", "agent"})

    result = run_install_args(
        home_dir,
        [
            "--yes",
            "--repo",
            str(repo),
            "--hosts",
            "all",
            "--execution-clis",
            "cursor",
            "--existing",
            "overwrite",
        ],
        with_fake_path(fake_bin),
    )

    assert result.returncode == 0, result.stdout + result.stderr
    assert load_deployed_config(home_dir)["installHosts"] == ["codex"]


def test_empty_hosts_argument_fails(tmp_path):
    home_dir = tmp_path / "home"
    repo = make_repo(tmp_path / "demo-repo")
    fake_bin = make_fake_bin(tmp_path, {"node", "git", "codex"})

    result = run_install_args(
        home_dir,
        [
            "--yes",
            "--repo",
            str(repo),
            "--hosts",
            ",",
            "--execution-clis",
            "codex",
        ],
        with_fake_path(fake_bin),
    )

    assert result.returncode != 0
    assert "--hosts requires at least one host or all" in result.stderr


def test_execution_clis_all_selects_detected_execution_clis(tmp_path):
    home_dir = tmp_path / "home"
    repo = make_repo(tmp_path / "demo-repo")
    fake_bin = make_fake_bin(tmp_path, {"node", "git", "agent", "codex"})

    result = run_install_args(
        home_dir,
        [
            "--yes",
            "--repo",
            str(repo),
            "--hosts",
            "codex",
            "--execution-clis",
            "all",
            "--existing",
            "overwrite",
        ],
        with_fake_path(fake_bin),
    )

    assert result.returncode == 0, result.stdout + result.stderr
    assert load_deployed_config(home_dir)["executionClis"] == ["cursor", "codex"]


def test_explicit_missing_execution_cli_fails(tmp_path):
    home_dir = tmp_path / "home"
    repo = make_repo(tmp_path / "demo-repo")
    fake_bin = make_fake_bin(tmp_path, {"node", "git", "codex"})

    result = run_install_args(
        home_dir,
        [
            "--yes",
            "--repo",
            str(repo),
            "--hosts",
            "codex",
            "--execution-clis",
            "opencode",
        ],
        with_fake_path(fake_bin),
    )

    assert result.returncode != 0
    assert "selected execution CLI is not installed: opencode" in result.stderr


def test_explicit_custom_single_host_uses_canonical_source_and_symlink(tmp_path):
    home_dir = tmp_path / "home"
    repo = make_repo(tmp_path / "demo-repo")
    fake_bin = make_fake_bin(tmp_path, {"node", "git", "openclaw", "claude"})

    result = run_install_args(
        home_dir,
        [
            "--yes",
            "--repo",
            str(repo),
            "--install-mode",
            "custom",
            "--hosts",
            "openclaw",
            "--execution-clis",
            "claude-code",
            "--existing",
            "overwrite",
        ],
        with_fake_path(fake_bin),
    )

    assert result.returncode == 0, result.stdout + result.stderr
    assert deployed_skill_path(home_dir).exists()
    assert deployed_host_path(home_dir, "openclaw").is_symlink()
    config = load_deployed_config(home_dir)
    assert config["installMode"] == "custom"
    assert config["installHosts"] == ["openclaw"]


def test_existing_backup_skip_and_overwrite_for_install_target(tmp_path):
    repo = make_repo(tmp_path / "demo-repo")
    fake_bin = make_fake_bin(tmp_path, {"node", "git", "codex"})
    env = with_fake_path(fake_bin)

    backup_home = tmp_path / "backup-home"
    old_target = backup_home / ".agents" / "skills" / "agent-repo-router"
    old_target.mkdir(parents=True)
    (old_target / "old.txt").write_text("old")
    backup_result = run_install_args(backup_home, base_args(repo)[:-1] + ["backup"], env)
    assert backup_result.returncode == 0, backup_result.stdout + backup_result.stderr
    assert (backup_home / ".agents" / "skills" / "agent-repo-router_backup_0" / "old.txt").exists()

    skip_home = tmp_path / "skip-home"
    skip_target = skip_home / ".agents" / "skills" / "agent-repo-router"
    skip_target.mkdir(parents=True)
    (skip_target / "old.txt").write_text("old")
    skip_result = run_install_args(skip_home, base_args(repo)[:-1] + ["skip"], env)
    assert skip_result.returncode == 0, skip_result.stdout + skip_result.stderr
    assert (skip_target / "old.txt").exists()
    assert not deployed_config_path(skip_home).exists()

    overwrite_home = tmp_path / "overwrite-home"
    overwrite_target = overwrite_home / ".agents" / "skills" / "agent-repo-router"
    overwrite_target.mkdir(parents=True)
    (overwrite_target / "old.txt").write_text("old")
    overwrite_result = run_install_args(overwrite_home, base_args(repo), env)
    assert overwrite_result.returncode == 0, overwrite_result.stdout + overwrite_result.stderr
    assert not (overwrite_target / "old.txt").exists()
    assert deployed_config_path(overwrite_home).exists()


def test_existing_backup_for_host_link_target(tmp_path):
    home_dir = tmp_path / "home"
    repo = make_repo(tmp_path / "demo-repo")
    openclaw_target = deployed_host_path(home_dir, "openclaw")
    openclaw_target.mkdir(parents=True)
    (openclaw_target / "old.txt").write_text("old")
    fake_bin = make_fake_bin(tmp_path, {"node", "git", "openclaw", "claude"})

    result = run_install_args(
        home_dir,
        [
            "--yes",
            "--repo",
            str(repo),
            "--install-mode",
            "global",
            "--hosts",
            "openclaw",
            "--execution-clis",
            "claude-code",
            "--existing",
            "backup",
        ],
        with_fake_path(fake_bin),
    )

    assert result.returncode == 0, result.stdout + result.stderr
    assert (home_dir / ".openclaw" / "skills" / "agent-repo-router_backup_0" / "old.txt").exists()
    assert openclaw_target.is_symlink()


def test_interactive_skip_preflight_avoids_partial_canonical_mutation(tmp_path):
    home_dir = tmp_path / "home"
    repo = make_repo(tmp_path / "demo-repo")
    canonical_target = deployed_skill_path(home_dir).parent
    openclaw_target = deployed_host_path(home_dir, "openclaw")
    fake_bin = make_fake_bin(tmp_path, {"node", "git", "openclaw", "claude"})

    canonical_target.mkdir(parents=True)
    (canonical_target / "old.txt").write_text("old-canonical")
    openclaw_target.mkdir(parents=True)
    (openclaw_target / "old.txt").write_text("old-openclaw")

    result = run_install(
        home_dir,
        manual_install_input("1", "1", [str(repo)], install_mode="1") + "2\n3\n",
        with_fake_path(fake_bin),
    )

    assert result.returncode == 0, result.stdout + result.stderr
    assert "Skipping install because host skill target already exists" in result.stdout
    assert (canonical_target / "old.txt").read_text() == "old-canonical"
    assert (openclaw_target / "old.txt").read_text() == "old-openclaw"
    assert not canonical_target.with_name("agent-repo-router_backup_0").exists()


def test_local_cache_auto_uses_local_files(tmp_path):
    home_dir = tmp_path / "home"
    repo = make_repo(tmp_path / "demo-repo")
    fake_bin = make_fake_bin(tmp_path, {"node", "git", "codex"})
    env = with_fake_path(fake_bin)
    env["AGENT_REPO_ROUTER_USE_LOCAL_CACHE"] = "auto"
    env["AGENT_REPO_ROUTER_REPO"] = "invalid/invalid"

    result = run_install_args(home_dir, base_args(repo), env)

    assert result.returncode == 0, result.stdout + result.stderr
    assert deployed_config_path(home_dir).exists()
