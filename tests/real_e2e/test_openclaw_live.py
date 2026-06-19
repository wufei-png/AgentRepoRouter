"""Opt-in real OpenClaw end-to-end tests."""

from __future__ import annotations

import os
from pathlib import Path

import pytest

from testsupport import (
    PROJECT_ROOT,
    build_judge_prompt,
    collect_agent_output_text,
    copy_fixture_repo,
    ensure_openclaw_healthy,
    extract_tagged_json,
    initialize_git_repo,
    run_command,
    run_openclaw_agent,
    run_repo_tests,
    temporary_router_skill_override,
)

pytestmark = pytest.mark.real_e2e


@pytest.fixture(scope="module")
def real_e2e_config():
    if os.environ.get("AGENT_REPO_ROUTER_REAL_E2E") != "1":
        pytest.skip("Set AGENT_REPO_ROUTER_REAL_E2E=1 to run live OpenClaw tests.")

    agent_id = os.environ.get("AGENT_REPO_ROUTER_REAL_E2E_AGENT")
    agent_workspace = os.environ.get("AGENT_REPO_ROUTER_REAL_E2E_AGENT_WORKSPACE")
    if not agent_id or not agent_workspace:
        pytest.skip(
            "AGENT_REPO_ROUTER_REAL_E2E_AGENT and AGENT_REPO_ROUTER_REAL_E2E_AGENT_WORKSPACE are required for live tests."
        )

    config = {
        "agent_id": agent_id,
        "agent_workspace": Path(agent_workspace).expanduser(),
        "judge_agent": os.environ.get("AGENT_REPO_ROUTER_REAL_E2E_JUDGE_AGENT") or agent_id,
        "language": os.environ.get("AGENT_REPO_ROUTER_REAL_E2E_LANGUAGE") or "en",
        "thinking": os.environ.get("AGENT_REPO_ROUTER_REAL_E2E_THINKING") or "medium",
    }

    ensure_openclaw_healthy()
    return config


def _run_judge(real_e2e_config: dict, prompt: str) -> dict:
    _, payload = run_openclaw_agent(
        real_e2e_config["judge_agent"],
        prompt,
        thinking="low",
        timeout=300,
    )
    return extract_tagged_json(collect_agent_output_text(payload), "AGENT_REPO_ROUTER_JUDGE")


def test_docs_question_is_answered_correctly_live(tmp_path, real_e2e_config):
    backend_repo = copy_fixture_repo(
        PROJECT_ROOT / "tests" / "repos" / "test-backend",
        tmp_path / "test-backend",
    )
    docs_repo = copy_fixture_repo(
        PROJECT_ROOT / "tests" / "repos" / "test-docs",
        tmp_path / "test-docs",
    )
    initialize_git_repo(backend_repo)
    initialize_git_repo(docs_repo)

    repos = [
        {
            "name": "test-backend",
            "path": str(backend_repo),
            "aliases": [],
            "skills": {},
            "agents": {},
        },
        {
            "name": "test-docs",
            "path": str(docs_repo),
            "aliases": [],
            "skills": {},
            "agents": {},
        },
    ]
    task = "what is the deployment process in test-docs?"
    message = f"use skill agent-repo-router to solve the following task: {task}"

    with temporary_router_skill_override(
        real_e2e_config["agent_workspace"],
        language=real_e2e_config["language"],
        agents=["claude-code", "opencode", "cursor", "codex"],
        repos=repos,
    ):
        _, payload = run_openclaw_agent(
            real_e2e_config["agent_id"],
            message,
            thinking=real_e2e_config["thinking"],
        )

    output_text = collect_agent_output_text(payload)
    reference_material = (docs_repo / "docs" / "deployment.md").read_text()

    judge_prompt = build_judge_prompt(
        task=task,
        success_criteria=(
            "The answer should accurately describe the deployment process from the test-docs "
            "repository, including the major rollout steps and the health-check command."
        ),
        reference_material=reference_material,
        agent_output_text=output_text,
        repo_diff=run_command(["git", "diff", "--stat"], cwd=docs_repo).stdout,
        repo_test_output="docs repo does not define automated tests",
    )
    verdict = _run_judge(real_e2e_config, judge_prompt)

    assert verdict["pass"], verdict["reasons"]


def test_backend_bugfix_completes_successfully_live(tmp_path, real_e2e_config):
    backend_repo = copy_fixture_repo(
        PROJECT_ROOT / "tests" / "repos" / "test-backend",
        tmp_path / "test-backend",
    )
    docs_repo = copy_fixture_repo(
        PROJECT_ROOT / "tests" / "repos" / "test-docs",
        tmp_path / "test-docs",
    )
    initialize_git_repo(backend_repo)
    initialize_git_repo(docs_repo)

    repos = [
        {
            "name": "test-backend",
            "path": str(backend_repo),
            "aliases": [],
            "skills": {},
            "agents": {},
        },
        {
            "name": "test-docs",
            "path": str(docs_repo),
            "aliases": [],
            "skills": {},
            "agents": {},
        },
    ]
    task = (
        "fix the login bug in test-backend so invalid passwords are rejected, "
        "use the project's build_and_test skill, and make sure npm test passes"
    )
    message = f"use skill agent-repo-router to solve the following task: {task}"

    with temporary_router_skill_override(
        real_e2e_config["agent_workspace"],
        language=real_e2e_config["language"],
        agents=["claude-code", "opencode", "cursor", "codex"],
        repos=repos,
    ):
        _, payload = run_openclaw_agent(
            real_e2e_config["agent_id"],
            message,
            thinking=real_e2e_config["thinking"],
            timeout=900,
        )

    output_text = collect_agent_output_text(payload)
    repo_test_result = run_repo_tests(backend_repo)
    reference_material = (backend_repo / "test" / "auth.test.js").read_text()

    judge_prompt = build_judge_prompt(
        task=task,
        success_criteria=(
            "The implementation should reject invalid login credentials in test-backend, "
            "and the repository tests should pass after the change."
        ),
        reference_material=reference_material,
        agent_output_text=output_text,
        repo_diff=run_command(["git", "diff", "--stat"], cwd=backend_repo).stdout,
        repo_test_output=(repo_test_result.stdout + repo_test_result.stderr),
    )
    verdict = _run_judge(real_e2e_config, judge_prompt)

    assert repo_test_result.returncode == 0, repo_test_result.stdout + repo_test_result.stderr
    assert verdict["pass"], verdict["reasons"]
