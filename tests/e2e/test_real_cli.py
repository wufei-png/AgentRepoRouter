"""End-to-end tests for installer edge cases."""

from testsupport import (
    load_deployed_config,
    make_fake_bin,
    run_install,
    with_fake_path,
)


def test_auto_scan_reprompts_when_root_directory_is_invalid(tmp_path):
    home_dir = tmp_path / "home"
    valid_root = tmp_path / "valid-root"
    fake_bin = make_fake_bin(tmp_path, {"node", "git", "openclaw", "claude"})

    (valid_root / "demo-repo" / ".git").mkdir(parents=True)

    user_input = f"1\n1\n1\n{tmp_path / 'missing-root'}\n1\n{valid_root}\n"
    result = run_install(home_dir, user_input, with_fake_path(fake_bin))

    assert result.returncode == 0, result.stdout + result.stderr
    assert f"Directory does not exist: {tmp_path / 'missing-root'}" in result.stdout
    deployed_config = load_deployed_config(home_dir)
    assert deployed_config["schemaVersion"] == 1
    assert deployed_config["repos"] == [
        {
            "name": "demo-repo",
            "path": str((valid_root / "demo-repo").resolve()),
            "type": "backend",
        }
    ]
