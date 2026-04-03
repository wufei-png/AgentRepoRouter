"""End-to-end tests for install.sh project discovery."""

from testsupport import (
    PROJECT_ROOT,
    auto_scan_input,
    load_deployed_config,
    make_fake_bin,
    run_install,
    with_fake_path,
)


def test_auto_scan_filters_duplicate_project_names(tmp_path):
    home_dir = tmp_path / "home"
    scan_root = tmp_path / "scan-root"
    fake_bin = make_fake_bin(tmp_path, {"node", "git", "openclaw", "claude", "opencode"})

    (scan_root / "team-a" / "shared" / ".git").mkdir(parents=True)
    (scan_root / "team-b" / "shared" / ".git").mkdir(parents=True)
    (scan_root / "docs-site" / ".git").mkdir(parents=True)

    result = run_install(
        home_dir,
        auto_scan_input("1", "1,2", str(scan_root)),
        with_fake_path(fake_bin),
    )

    deployed_config = load_deployed_config(home_dir)
    repo_names = [repo["name"] for repo in deployed_config["repos"]]
    shared_paths = {
        str((scan_root / "team-a" / "shared").resolve()),
        str((scan_root / "team-b" / "shared").resolve()),
    }

    assert result.returncode == 0, result.stdout + result.stderr
    assert deployed_config["schemaVersion"] == 1
    assert repo_names.count("shared") == 1
    assert set(repo_names) == {"shared", "docs-site"}
    assert "Duplicate project name filtered: shared" in result.stdout
    assert {
        repo["path"] for repo in deployed_config["repos"] if repo["name"] == "shared"
    } <= shared_paths


def test_manual_input_rejects_relative_paths_and_keeps_absolute_paths(tmp_path):
    home_dir = tmp_path / "home"
    fake_bin = make_fake_bin(tmp_path, {"node", "git", "openclaw", "claude"})

    user_input = f"1\n1\n2\nrelative/path\n{PROJECT_ROOT}\n\n"
    result = run_install(home_dir, user_input, with_fake_path(fake_bin))

    assert result.returncode == 0, result.stdout + result.stderr
    assert "Please enter an absolute path: relative/path" in result.stdout
    assert load_deployed_config(home_dir)["repos"] == [
        {
            "name": "OrchAI",
            "path": str(PROJECT_ROOT),
            "type": "backend",
        }
    ]
