"""Configuration loader for OrchAI"""

import logging
import threading
from pathlib import Path
from typing import Any, Optional

import yaml

logger = logging.getLogger(__name__)


class Config:
    # TODO: Fix singleton without thread safety - 修复单例模式无线程安全 (Critical #4)
    # Use lock to prevent race conditions in multi-threaded environments
    _instance: Optional["Config"] = None
    _lock = threading.Lock()
    _config_dir: Path

    def __new__(cls, config_dir: str = "config"):
        # Double-checked locking pattern for thread safety
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = super().__new__(cls)
                    cls._instance._config_dir = Path(config_dir)
                    cls._instance._load()
        return cls._instance

    def _load(self) -> None:
        self._load_openclaw()
        self._load_agents()
        self._load_mcp()
        self._load_projects()
        self._load_router_config()

    def _load_yaml_safe(self, path: Path, default: Any = None) -> Any:
        """TODO: Fix no YAML error handling - 修复无 YAML 错误处理 (Medium #13)
        Safely load YAML file with error handling"""
        try:
            with open(path, encoding="utf-8") as f:
                return yaml.safe_load(f) or {}
        except yaml.YAMLError as e:
            logger.error(f"Failed to parse YAML file {path}: {e}")
            return default if default is not None else {}
        except OSError as e:
            logger.warning(f"Failed to read file {path}: {e}")
            return default if default is not None else {}

    def _load_openclaw(self) -> None:
        path = self._config_dir / "openclaw.yaml"
        # TODO: Fix no YAML error handling - 修复无 YAML 错误处理 (Medium #13)
        self.openclaw = self._load_yaml_safe(
            path,
            {
                "server": {},
                "workspace": {},
                "agents_dir": "./config/agents",
            },
        )

    def _load_agents(self) -> None:
        path = self._config_dir / "agents.yaml"
        # TODO: Fix no YAML error handling - 修复无 YAML 错误处理 (Medium #13)
        data = self._load_yaml_safe(path)
        self.agents = data.get("agents", []) if isinstance(data, dict) else []

    def _load_mcp(self) -> None:
        path = self._config_dir / "mcp.yaml"
        # TODO: Fix no YAML error handling - 修复无 YAML 错误处理 (Medium #13)
        data = self._load_yaml_safe(path)
        self.mcp_servers = data.get("servers", []) if isinstance(data, dict) else []

    def _load_projects(self) -> None:
        path = self._config_dir / "projects.yaml"
        # TODO: Fix no YAML error handling - 修复无 YAML 错误处理 (Medium #13)
        data = self._load_yaml_safe(path)
        self.projects = data.get("repos", []) if isinstance(data, dict) else []

    def _load_router_config(self) -> None:
        path = self._config_dir / "router_config.yaml"
        # TODO: Fix no YAML error handling - 修复无 YAML 错误处理 (Medium #13)
        self.router_config = self._load_yaml_safe(
            path, {"fallback": {"enabled": True, "max_retries": 3}}
        )

    def get_agent(self, name: str) -> dict[str, Any] | None:
        for agent in self.agents:
            if agent.get("name") == name:
                return agent
        return None

    def get_enabled_agents(self) -> list[str]:
        # TODO: Fix KeyError in get_enabled_agents - 修复 get_enabled_agents 中的 KeyError (Critical #3)
        # Use safe key access to avoid KeyError on malformed data
        return [a.get("name", "unknown") for a in self.agents if a.get("enabled", True)]

    def get_project(self, name: str) -> dict[str, Any] | None:
        # TODO: Fix missing validation in get_project - 修复 get_project 中缺失的验证 (Critical #2)
        # Validate proj is a dict before accessing keys
        for proj in self.projects:
            if isinstance(proj, dict) and proj.get("name") == name:
                return proj
        return None

    def reload(self) -> None:
        # TODO: Fix reload() doesn't clear singleton cache - 修复 reload() 不清除单例缓存的问题 (Low #11)
        # Reload config with error handling
        try:
            self._load()
        except Exception as e:
            logger.error(f"Failed to reload config: {e}")
            # Don't re-raise - keep existing config on failure


def load_config(config_dir: str = "config") -> Config:
    return Config(config_dir)
