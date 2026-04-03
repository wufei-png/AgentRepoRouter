"""Unit tests for install script environment checks."""

from testsupport import make_fake_bin, run_install, with_fake_path


def test_install_rejects_node_below_minimum_version(tmp_path):
    home_dir = tmp_path / "home"
    fake_bin = make_fake_bin(
        tmp_path,
        {"node", "git", "openclaw"},
        node_version="v16.20.0",
    )

    result = run_install(home_dir, "", with_fake_path(fake_bin))

    assert result.returncode != 0
    assert "Node.js 18+ is required" in result.stdout


def test_install_fails_when_no_supported_cli_is_available(tmp_path):
    home_dir = tmp_path / "home"
    fake_bin = make_fake_bin(tmp_path, {"node", "git", "openclaw"})

    result = run_install(home_dir, "1\n", with_fake_path(fake_bin))

    assert result.returncode != 0
    assert "No supported CLI tools were found" in result.stdout
