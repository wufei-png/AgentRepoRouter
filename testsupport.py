"""Shared test helpers for AgentRepoRouter installer tests."""

from __future__ import annotations

import contextlib
import json
import os
import re
import stat
import subprocess
import shutil
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent
INSTALL_SCRIPT = PROJECT_ROOT / "scripts" / "install.sh"
VALIDATE_REPO_MAPPINGS_SCRIPT = PROJECT_ROOT / "scripts" / "validate_repo_mappings.sh"
SKILL_SLUG = "agent-repo-router"
GLOBAL_SKILL_REL = Path(".agents/skills") / SKILL_SLUG
DEPLOYED_SKILL_REL = GLOBAL_SKILL_REL / "SKILL.md"
DEPLOYED_CONFIG_REL = GLOBAL_SKILL_REL / "references/repo_mappings.json"
REPO_MAPPINGS_SCHEMA_VERSION = 2


HOST_SKILL_RELS = {
    "openclaw": Path(".openclaw/skills") / SKILL_SLUG,
    "claude-code": Path(".claude/skills") / SKILL_SLUG,
    "opencode": Path(".config/opencode/skills") / SKILL_SLUG,
    "codex": GLOBAL_SKILL_REL,
    "hermes": Path(".hermes/skills/software-development") / SKILL_SLUG,
}


def deployed_skill_path(home_dir: Path) -> Path:
    return home_dir / DEPLOYED_SKILL_REL


def deployed_config_path(home_dir: Path) -> Path:
    return home_dir / DEPLOYED_CONFIG_REL


def deployed_host_path(home_dir: Path, host: str) -> Path:
    return home_dir / HOST_SKILL_RELS[host]


def deployed_host_skill_path(home_dir: Path, host: str) -> Path:
    return deployed_host_path(home_dir, host) / "SKILL.md"


def deployed_host_config_path(home_dir: Path, host: str) -> Path:
    return deployed_host_path(home_dir, host) / "references" / "repo_mappings.json"


def backup_roots(home_dir: Path) -> list[Path]:
    backup_base = home_dir / "tmp" / "agent-repo-router-skill-backups"
    if not backup_base.exists():
        return []
    return sorted(backup_base.glob("install-*"))


def load_deployed_config(home_dir: Path) -> dict:
    return json.loads(deployed_config_path(home_dir).read_text())


def load_host_deployed_config(home_dir: Path, host: str) -> dict:
    return json.loads(deployed_host_config_path(home_dir, host).read_text())


def validate_repo_mappings_file(config_path: Path) -> None:
    result = subprocess.run(
        [str(VALIDATE_REPO_MAPPINGS_SCRIPT), str(config_path)],
        text=True,
        capture_output=True,
        cwd=PROJECT_ROOT,
        check=False,
    )
    if result.returncode != 0:
        raise AssertionError(result.stderr or result.stdout or f"validation failed for {config_path}")


def write_repo_mappings(
    config_path: Path,
    agents: list[str],
    repos: list[dict],
    *,
    install_mode: str = "global",
    install_hosts: list[str] | None = None,
) -> dict:
    normalized_repos = []
    for repo in repos:
        normalized_repos.append(
            {
                "name": repo["name"],
                "path": repo["path"],
                "aliases": repo.get("aliases", []),
                "skills": repo.get("skills", {}),
                "agents": repo.get("agents", {}),
            }
        )

    payload = {
        "schemaVersion": REPO_MAPPINGS_SCHEMA_VERSION,
        "installMode": install_mode,
        "installHosts": install_hosts or ["global"],
        "executionClis": agents,
        "repos": normalized_repos,
    }
    config_path.parent.mkdir(parents=True, exist_ok=True)
    config_path.write_text(json.dumps(payload, indent=2) + "\n")
    validate_repo_mappings_file(config_path)
    return payload


def run_install(
    home_dir: Path,
    user_input: str,
    extra_env: dict[str, str] | None = None,
) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env["HOME"] = str(home_dir)
    env["TMPDIR"] = str(home_dir / "tmp")
    env.setdefault("AGENT_REPO_ROUTER_USE_LOCAL_CACHE", "true")
    if extra_env:
        env.update(extra_env)

    home_dir.mkdir(parents=True, exist_ok=True)

    return subprocess.run(
        ["/bin/bash", str(INSTALL_SCRIPT)],
        input=user_input,
        text=True,
        capture_output=True,
        cwd=PROJECT_ROOT,
        env=env,
        check=False,
    )


def run_install_args(
    home_dir: Path,
    args: list[str],
    extra_env: dict[str, str] | None = None,
    input_text: str | None = None,
) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env["HOME"] = str(home_dir)
    env["TMPDIR"] = str(home_dir / "tmp")
    env.setdefault("AGENT_REPO_ROUTER_USE_LOCAL_CACHE", "true")
    if extra_env:
        env.update(extra_env)

    home_dir.mkdir(parents=True, exist_ok=True)

    return subprocess.run(
        ["/bin/bash", str(INSTALL_SCRIPT), *args],
        input=input_text,
        text=True,
        capture_output=True,
        cwd=PROJECT_ROOT,
        env=env,
        check=False,
    )


def manual_install_input(
    language: str,
    clis: str,
    paths: list[str],
    *,
    install_mode: str = "1",
    install_hosts: str | None = None,
) -> str:
    lines = [language, install_mode]
    if install_hosts is not None:
        lines.append(install_hosts)
    lines.extend([clis, "2", *paths, ""])
    return "\n".join(lines) + "\n"


def auto_scan_input(
    language: str,
    clis: str,
    scan_root: str | list[str],
    *,
    install_mode: str = "1",
    install_hosts: str | None = None,
) -> str:
    lines = [language, install_mode]
    if install_hosts is not None:
        lines.append(install_hosts)
    scan_roots = [scan_root] if isinstance(scan_root, str) else scan_root
    lines.extend([clis, "1", *scan_roots, ""])
    return "\n".join(lines) + "\n"


def make_fake_bin(tmp_path: Path, available: set[str], node_version: str = "v24.13.0") -> Path:
    bin_dir = tmp_path / "fake-bin"
    bin_dir.mkdir()
    real_node = shutil.which("node")
    if real_node is None:
        raise AssertionError("node is required to build the fake bin test environment")

    scripts = {
        "node": f"""#!/bin/sh
if [ "$1" = "-v" ]; then
  echo "{node_version}"
  exit 0
fi
exec "{real_node}" "$@"
""",
        "git": "#!/bin/sh\nexit 0\n",
        "openclaw": "#!/bin/sh\nexit 0\n",
        "claude": "#!/bin/sh\nexit 0\n",
        "opencode": "#!/bin/sh\nexit 0\n",
        "agent": "#!/bin/sh\nexit 0\n",
        "codex": "#!/bin/sh\nexit 0\n",
        "hermes": "#!/bin/sh\nexit 0\n",
    }

    for name in available:
        script_path = bin_dir / name
        script_path.write_text(scripts[name])
        script_path.chmod(script_path.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)

    return bin_dir


def with_fake_path(bin_dir: Path) -> dict[str, str]:
    system_path = os.pathsep.join(["/usr/bin", "/bin", "/usr/sbin", "/sbin"])
    return {"PATH": f"{bin_dir}{os.pathsep}{system_path}"}


def collect_text_fragments(value: object) -> list[str]:
    if isinstance(value, str):
        return [value]
    if isinstance(value, list):
        fragments: list[str] = []
        for item in value:
            fragments.extend(collect_text_fragments(item))
        return fragments
    if isinstance(value, dict):
        fragments = []
        for item in value.values():
            fragments.extend(collect_text_fragments(item))
        return fragments
    return []


def parse_json_output(stdout: str) -> object:
    stdout = stdout.strip()
    if not stdout:
        raise ValueError("command produced empty stdout")

    try:
        return json.loads(stdout)
    except json.JSONDecodeError:
        pass

    for line in reversed(stdout.splitlines()):
        line = line.strip()
        if not line:
            continue
        try:
            return json.loads(line)
        except json.JSONDecodeError:
            continue

    raise ValueError(f"unable to parse JSON output: {stdout[:400]}")


def extract_tagged_json(text: str, tag: str) -> dict:
    pattern = re.compile(rf"^{re.escape(tag)}\s+(\{{.*\}})$", re.MULTILINE)
    match = pattern.search(text)
    if not match:
        raise ValueError(f"missing tagged JSON line for {tag}")
    return json.loads(match.group(1))


def run_command(
    args: list[str],
    *,
    cwd: Path | None = None,
    env: dict[str, str] | None = None,
    timeout: int = 300,
) -> subprocess.CompletedProcess[str]:
    merged_env = os.environ.copy()
    if env:
        merged_env.update(env)

    return subprocess.run(
        args,
        text=True,
        capture_output=True,
        cwd=cwd or PROJECT_ROOT,
        env=merged_env,
        timeout=timeout,
        check=False,
    )


def ensure_openclaw_healthy(openclaw_bin: str = "openclaw") -> dict:
    result = run_command([openclaw_bin, "health", "--json"], timeout=30)
    if result.returncode != 0:
        raise AssertionError(result.stderr or result.stdout or "openclaw health failed")

    payload = parse_json_output(result.stdout)
    if not isinstance(payload, dict):
        raise AssertionError("openclaw health --json did not return an object")

    if payload.get("ok") is False or payload.get("healthy") is False:
        raise AssertionError(f"openclaw gateway is unhealthy: {payload}")

    return payload


def run_openclaw_agent(
    agent_id: str,
    message: str,
    *,
    thinking: str = "medium",
    openclaw_bin: str = "openclaw",
    timeout: int = 600,
) -> tuple[subprocess.CompletedProcess[str], object]:
    result = run_command(
        [
            openclaw_bin,
            "agent",
            "--agent",
            agent_id,
            "--message",
            message,
            "--thinking",
            thinking,
            "--json",
        ],
        timeout=timeout,
    )
    if result.returncode != 0:
        raise AssertionError(result.stderr or result.stdout or "openclaw agent command failed")

    return result, parse_json_output(result.stdout)


def collect_agent_output_text(payload: object) -> str:
    return "\n".join(fragment for fragment in collect_text_fragments(payload) if fragment.strip())


def copy_fixture_repo(source_repo: Path, destination: Path) -> Path:
    shutil.copytree(
        source_repo,
        destination,
        ignore=shutil.ignore_patterns(".git", "__pycache__", ".DS_Store"),
    )
    return destination


def initialize_git_repo(repo_path: Path) -> None:
    commands = [
        ["git", "init", "-q"],
        ["git", "config", "user.email", "real-e2e@example.com"],
        ["git", "config", "user.name", "AgentRepoRouter Real E2E"],
        ["git", "add", "-A"],
        ["git", "commit", "-q", "-m", "baseline"],
    ]
    for command in commands:
        result = run_command(command, cwd=repo_path)
        if result.returncode != 0:
            raise AssertionError(result.stderr or result.stdout or f"git command failed: {command}")


def run_repo_tests(repo_path: Path) -> subprocess.CompletedProcess[str]:
    package_json = repo_path / "package.json"
    if package_json.exists():
        return run_command(["npm", "test"], cwd=repo_path, timeout=300)
    return run_command(["true"], cwd=repo_path)


@contextlib.contextmanager
def temporary_router_skill_override(
    agent_workspace: Path,
    *,
    language: str,
    agents: list[str],
    repos: list[dict],
):
    workspace_skill_dir = agent_workspace / "skills" / SKILL_SLUG
    backup_dir = workspace_skill_dir.with_name(f"{SKILL_SLUG}.__agent_repo_router_backup__")

    if backup_dir.exists():
        shutil.rmtree(backup_dir)

    if workspace_skill_dir.exists():
        shutil.move(str(workspace_skill_dir), str(backup_dir))

    try:
        template_name = "SKILL.zh.md" if language == "zh" else "SKILL.en.md"
        template_path = PROJECT_ROOT / "skills" / SKILL_SLUG / template_name
        references_dir = PROJECT_ROOT / "skills" / SKILL_SLUG / "references"

        workspace_skill_dir.mkdir(parents=True, exist_ok=True)
        workspace_references_dir = workspace_skill_dir / "references"
        workspace_references_dir.mkdir(parents=True, exist_ok=True)
        (workspace_skill_dir / "SKILL.md").write_text(template_path.read_text())
        for reference_path in references_dir.glob("*.md"):
            shutil.copy2(reference_path, workspace_references_dir / reference_path.name)
        write_repo_mappings(workspace_references_dir / "repo_mappings.json", agents, repos)
        yield workspace_skill_dir
    finally:
        if workspace_skill_dir.exists():
            shutil.rmtree(workspace_skill_dir)
        if backup_dir.exists():
            shutil.move(str(backup_dir), str(workspace_skill_dir))


def build_judge_prompt(
    *,
    task: str,
    success_criteria: str,
    reference_material: str,
    agent_output_text: str,
    repo_diff: str,
    repo_test_output: str,
) -> str:
    return f"""You are the judge for an AgentRepoRouter real e2e test.
Return exactly one line in the format:
AGENT_REPO_ROUTER_JUDGE {{"pass":true|false,"reasons":["..."]}}

Task:
{task}

Success criteria:
{success_criteria}

Reference material:
{reference_material}

Observed agent output:
{agent_output_text}

Observed git diff:
{repo_diff}

Observed repo test output:
{repo_test_output}

Pass only if the observable task result satisfies the success criteria using the reference material.
Ignore internal routing details.
For code tasks, if the repo tests fail, return pass=false.
"""
