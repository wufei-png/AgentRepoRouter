"""E2E tests for CLI selection and language deployment."""

from testsupport import (
    PROJECT_ROOT,
    deployed_skill_path,
    load_deployed_config,
    make_fake_bin,
    manual_install_input,
    run_install,
    with_fake_path,
)


def test_cli_selection_reprompts_until_only_installed_tools_are_chosen(tmp_path):
    home_dir = tmp_path / "home"
    fake_bin = make_fake_bin(tmp_path, {"node", "git", "openclaw", "claude"})

    user_input = f"1\n2\n1\n2\n{PROJECT_ROOT}\n\n"
    result = run_install(home_dir, user_input, with_fake_path(fake_bin))

    assert result.returncode == 0, result.stdout + result.stderr
    assert "Selected CLI is not installed: opencode" in result.stdout
    assert "Please select at least one installed CLI." in result.stdout
    assert load_deployed_config(home_dir)["schemaVersion"] == 1
    assert load_deployed_config(home_dir)["agents"] == ["claude-code"]


def test_english_selection_deploys_only_skill_md(tmp_path):
    home_dir = tmp_path / "home"
    fake_bin = make_fake_bin(tmp_path, {"node", "git", "openclaw", "opencode"})

    result = run_install(
        home_dir,
        manual_install_input("2", "2", [str(PROJECT_ROOT)]),
        with_fake_path(fake_bin),
    )

    skill_path = deployed_skill_path(home_dir)

    assert result.returncode == 0, result.stdout + result.stderr
    assert "Route coding tasks to appropriate repos and agents" in skill_path.read_text()
    assert not (skill_path.parent / "SKILL.zh.md").exists()
    assert not (skill_path.parent / "SKILL.en.md").exists()
