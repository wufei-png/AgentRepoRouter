"""Router logic - pure functions for OpenClaw skill"""

import json
from pathlib import Path
from typing import Any

from .config import Config

# TODO: Fix magic number for confidence threshold - 修复置信度阈值的魔数 (Medium #11)
# Make confidence threshold configurable with explanation
# 1.5 means the top match needs 50% more score than second best to be considered unique
# This prevents ambiguous routing when scores are close together
DEFAULT_CONFIDENCE_THRESHOLD = 1.5


def load_repos(
    mappings_file: str = "skills/router/repo_mappings.json",
    config_dir: str = "config",
) -> list[dict[str, Any]]:
    """Load repos from mappings file and config"""
    mappings_path = Path(mappings_file)
    config = Config(config_dir)
    repos = []

    if mappings_path.exists():
        with open(mappings_path, encoding="utf-8") as f:
            repos = json.load(f).get("repos", [])

    # TODO: Fix inefficient loop in load_repos - 修复 load_repos 中的低效循环问题 (High #3)
    # Use dict/set for O(1) lookup instead of O(n) for each project
    existing_names = {r.get("name") for r in repos if r.get("name")}
    for proj in config.projects:
        # Use r.get("name") to safely access key, avoid KeyError if malformed
        proj_name = proj.get("name")
        if proj_name and proj_name not in existing_names:
            repos.append(proj)
            existing_names.add(proj_name)

    return repos


def route(
    task: str,
    repos: list[dict[str, Any]],
    confidence_threshold: float = DEFAULT_CONFIDENCE_THRESHOLD,
) -> dict[str, Any]:
    """Route task to appropriate repo - pure function"""
    # TODO: Fix no input validation - 修复无输入验证的问题 (Medium #12)
    # Validate input parameters
    if not task or not isinstance(task, str):
        return {
            "found": False,
            "candidates": [],
            "reason": "Invalid task: must be non-empty string",
        }

    if not repos:
        return {"found": False, "candidates": [], "reason": "No repos configured"}

    task_lower = task.lower()
    matches = [(_match_score(task_lower, r), r) for r in repos]
    matches = [(s, r) for s, r in matches if s > 0]

    if not matches:
        return {"found": False, "candidates": [], "reason": "No repos matched"}

    matches.sort(reverse=True, key=lambda x: x[0])

    # TODO: Fix missing key validation in route - 修复 route() 中缺失的键验证 (High #6)
    # Validate that repo has required keys before accessing
    # Use configurable confidence threshold instead of hardcoded 1.5
    if len(matches) == 1 or matches[0][0] > matches[1][0] * confidence_threshold:
        repo = matches[0][1]
        # Validate required keys exist
        if "name" not in repo:
            return {
                "found": False,
                "candidates": [],
                "reason": "Repo missing required 'name' key",
            }

        return {
            "found": True,
            "repo": repo.get("name"),
            "agent": repo.get("agents", {}).get("primary", "claude-code"),
            "fallback": repo.get("agents", {}).get("fallback", []),
            "taskType": _classify_task(task_lower),
            "confidence": min(matches[0][0] / 10, 1.0),
        }

    return {
        "found": False,
        "candidates": [m[1].get("name", "unknown") for m in matches[:3]],
        "reason": "Multiple repos match the task",
    }


def _match_score(task: str, repo: dict[str, Any]) -> float:
    # TODO: Fix KeyError in _match_score - 修复 _match_score 中的 KeyError (Critical #2)
    # Safely access repo keys, use get() with defaults
    repo_name = repo.get("name", "").lower()
    score = sum(2.0 for k in repo.get("keywords", []) if k.lower() in task)
    if repo_name in task:
        score += 5.0
    if repo.get("description", "").lower() in task:
        score += 3.0
    return score


def _classify_task(task: str) -> str:
    # TODO: Fix missing input validation in _classify_task - 修复 _classify_task 中缺失的输入验证 (Critical #1)
    # Validate task is not None before processing
    if not task or not isinstance(task, str):
        return "qa"  # Default to qa for invalid input

    if any(w in task for w in ["add", "implement", "create", "new"]):
        return "feature"
    if any(w in task for w in ["fix", "bug", "error", "issue"]):
        return "bugfix"
    if any(w in task for w in ["refactor", "clean", "improve"]):
        return "refactor"
    if any(w in task for w in ["doc", "readme", "guide"]):
        return "docs"
    return "qa"


def add_mapping(
    repo_name: str,
    keywords: list[str],
    mappings_file: str = "skills/router/repo_mappings.json",
) -> dict[str, Any]:
    """Add keyword mapping to repo

    Returns:
        dict with 'success' key or error information
    """
    mappings_path = Path(mappings_file)
    repos = load_repos(mappings_file)

    for repo in repos:
        # TODO: Fix KeyError in add_mapping - 修复 add_mapping 中的 KeyError (Critical #2)
        # Use safe key access to avoid KeyError on malformed data
        if repo.get("name") == repo_name:
            repo["keywords"] = list(set(repo.get("keywords", []) + keywords))
            with open(mappings_path, "w", encoding="utf-8") as f:
                json.dump({"repos": repos}, f, indent=2)
            return {"success": True, "repo": repo_name, "keywords": repo["keywords"]}

    # TODO: Fix ValueError not caught in add_mapping - 修复 add_mapping 中 ValueError 未被捕获的问题 (High #2)
    # Return error dict instead of raising ValueError
    return {"success": False, "error": f"Repo not found: {repo_name}"}


class Router:
    """Router class for backward compatibility"""

    def __init__(
        self,
        mappings_file: str = "skills/router/repo_mappings.json",
        config_dir: str = "config",
        confidence_threshold: float = DEFAULT_CONFIDENCE_THRESHOLD,
    ):
        self.mappings_file = Path(mappings_file)
        self.config = Config(config_dir)
        self.repos = load_repos(str(mappings_file), config_dir)
        # TODO: Fix duplicate method - 修复重复方法的问题 (Low #17)
        # Store confidence threshold as instance variable
        self.confidence_threshold = confidence_threshold

    def route(self, task: str) -> dict[str, Any]:
        """Route task using instance configuration"""
        return route(task, self.repos, self.confidence_threshold)

    def route_sync(self, task: str) -> dict[str, Any]:
        """TODO: Fix duplicate method - 修复重复方法的问题 (Low #17)
        Synchronous route (alias for backward compatibility)

        Note: This method now delegates to route() with the configured
        confidence threshold. Use route() directly for clarity."""
        return self.route(task)

    def add_mapping(self, repo_name: str, keywords: list[str]) -> dict[str, Any]:
        return add_mapping(repo_name, keywords, str(self.mappings_file))
