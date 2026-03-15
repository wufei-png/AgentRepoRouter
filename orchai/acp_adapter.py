"""ACP adapter using acpx"""

import asyncio
import json
import logging
import shutil
from pathlib import Path
from typing import Any

from .config import Config

logger = logging.getLogger(__name__)


class ACPAdapter:
    """Adapter for acpx CLI"""

    def __init__(self, config_dir: str = "config"):
        self.config = Config(config_dir)
        self.CLI_COMMANDS = {
            "claude-code": "claude-code",
            "opencode": "opencode",
            "codex": "codex",
        }
        # TODO: Fix hardcoded npx dependency - 修复硬编码的 npx 依赖 (Critical #5)
        # Check for available Node.js package manager
        self._node_available = self._check_node_available()

    def _check_node_available(self) -> bool:
        """Check if Node.js and npm are available"""
        if shutil.which("npx") is not None:
            return True
        # Try alternative: check if node is available
        return shutil.which("node") is not None

    def get_enabled_agents(self) -> list[str]:
        # TODO: Fix potential duplicate agent names - 修复潜在的重复代理名称问题 (High #5)
        # Use dict.fromkeys to preserve order while removing duplicates
        agents = self.config.get_enabled_agents()
        return list(dict.fromkeys(agents))

    def is_agent_available(self, agent: str) -> bool:
        return agent in self.CLI_COMMANDS

    async def execute_with_fallback(
        self, repo: str, task: str, agents: list[str]
    ) -> dict[str, Any]:
        """Execute with fallback chain"""
        # TODO: Fix empty agent list not handled - 修复空代理列表未处理的问题 (Medium #15)
        # Explicitly handle empty agent list
        if not agents:
            raise ValueError(
                "No agents provided. Please specify at least one agent "
                "(e.g., ['opencode', 'claude-code', 'codex'])"
            )

        # TODO: Fix agents not validated before execution - 修复代理在执行前未验证的问题 (Medium #10)
        # Validate each agent before execution
        invalid_agents = [a for a in agents if not self.is_agent_available(a)]
        if invalid_agents:
            raise ValueError(
                f"Unknown agent(s): {invalid_agents}. "
                f"Available agents: {list(self.CLI_COMMANDS.keys())}"
            )

        last_error = None
        for agent in agents:
            try:
                result = await self.execute_agent(agent, repo, task)
                return {
                    "success": True,
                    "data": result,
                    "meta": {
                        "agent": agent,
                        "repo": repo,
                        "fallback_used": agent != agents[0],
                    },
                }
            except Exception as e:
                logger.warning("Agent %s failed: %s", agent, e)
                last_error = e
                continue
                # TODO: Fix duplicate/unreachable code - 修复重复/不可达代码 (Critical #1)
                # These lines were unreachable due to 'continue' above - removed dead code
        raise Exception(f"All agents failed for {repo}: {last_error}")

    async def execute_agent(self, agent: str, repo: str, task: str) -> dict[str, Any]:
        repo_path = Path(repo).resolve()

        result = await self._run_acpx_command(repo_path, agent, task)

        return result

    async def _run_acpx_command(
        self, cwd: Path, agent: str, task: str
    ) -> dict[str, Any]:
        # TODO: Fix hardcoded npx dependency - 修复硬编码的 npx 依赖 (Critical #5)
        # Check node availability before running command
        if not self._node_available:
            raise Exception(
                "Node.js/npm not found. Please install Node.js (v18+) and npm to use ACP adapters. "
                "Visit: https://nodejs.org/"
            )

        cmd = [
            "npx",
            "acpx@latest",
            "--cwd",
            str(cwd),
            "--format",
            "json",
            agent,
            "exec",
            task,
        ]

        logger.info("Running: %s", " ".join(cmd))

        # TODO: Fix no timeout for subprocess - 修复子进程无超时设置 (High #7)
        # Add configurable timeout to prevent indefinite hanging
        DEFAULT_TIMEOUT = 300  # 5 minutes default

        try:
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd=str(cwd),
            )

            try:
                stdout, stderr = await asyncio.wait_for(
                    process.communicate(), timeout=DEFAULT_TIMEOUT
                )
            except TimeoutError:
                # Kill the process on timeout
                process.kill()
                await process.wait()
                raise Exception(
                    f"acpx command timed out after {DEFAULT_TIMEOUT} seconds. "
                    "Consider increasing timeout or checking the agent response."
                )

            if process.returncode != 0:
                error_msg = stderr.decode() if stderr else "Unknown error"
                raise Exception(f"acpx failed: {error_msg}")

            output = stdout.decode()
            return self._parse_output(output)

        except FileNotFoundError:
            raise Exception(
                "npx not found. Please install Node.js and npm. "
                "Visit: https://nodejs.org/"
            )
        except TimeoutError:
            raise Exception(f"acpx command timed out: {' '.join(cmd)}")

    def _parse_output(self, output: str) -> dict[str, Any]:
        """Parse NDJSON output from acpx"""
        if not output.strip():
            return {"status": "completed", "events": []}

        events = []
        for line in output.strip().split("\n"):
            line = line.strip()
            if not line:
                continue
            try:
                events.append(json.loads(line))
            except json.JSONDecodeError as e:
                logger.warning("Failed to parse JSON line: %s - %s", line, e)
                continue

        return {"status": "completed", "events": events}
