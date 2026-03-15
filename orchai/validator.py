"""Result validator for CLI agent outputs"""

import hashlib
import logging
from pathlib import Path
from typing import Any

logger = logging.getLogger(__name__)


class ResultValidator:
    # TODO: Fix could capture excessive files - 修复可能捕获过多文件的问题 (Medium #14)
    # Add configurable limits to prevent memory issues on large repos
    DEFAULT_MAX_FILES = 10000  # Maximum files to track
    DEFAULT_MAX_FILE_SIZE_MB = 10  # Skip files larger than this

    ERROR_KEYWORDS = [
        "error",
        "failed",
        "exception",
        "traceback",
        "cannot",
        "unable to",
        "no such file",
        "command not found",
        "permission denied",
        "not found",
    ]

    def __init__(
        self,
        repo_path: str,
        max_files: int = DEFAULT_MAX_FILES,
        max_file_size_mb: int = DEFAULT_MAX_FILE_SIZE_MB,
    ):
        self.repo_path = Path(repo_path).resolve()
        self._file_hashes: dict[str, str] = {}
        self._initial_files: list[Path] = []
        # Store limits as instance variables
        self._max_files = max_files
        self._max_file_size_bytes = max_file_size_mb * 1024 * 1024

    def capture_initial_state(self, files_to_watch: list[str] | None = None) -> None:
        self._file_hashes = {}
        self._initial_files = []

        if files_to_watch:
            for f in files_to_watch:
                path = self.repo_path / f
                if path.exists():
                    self._initial_files.append(path)
                    self._file_hashes[str(path)] = self._hash_file(path)
        else:
            # TODO: Fix could capture excessive files - 修复可能捕获过多文件的问题 (Medium #14)
            # Add file count and size limits to prevent memory issues
            file_count = 0
            for path in self.repo_path.rglob("*"):
                if file_count >= self._max_files:
                    logger.warning(
                        f"Reached maximum file limit ({self._max_files}). "
                        f"Skipping remaining files."
                    )
                    break

                if path.is_file() and not self._is_ignored(path):
                    # Check file size to avoid hashing large files
                    try:
                        file_size = path.stat().st_size
                        if file_size > self._max_file_size_bytes:
                            logger.debug(
                                f"Skipping large file: {path} ({file_size} bytes)"
                            )
                            continue
                    except OSError as e:
                        logger.warning(f"Could not stat file {path}: {e}")
                        continue

                    self._initial_files.append(path)
                    self._file_hashes[str(path)] = self._hash_file(path)
                    file_count += 1

    def _is_ignored(self, path: Path) -> bool:
        ignore_patterns = {
            ".git",
            "__pycache__",
            ".pytest_cache",
            "node_modules",
            ".venv",
            "venv",
        }
        return any(part in ignore_patterns for part in path.parts)

    def _hash_file(self, path: Path) -> str:
        # TODO: Fix weak hash algorithm - 修复弱哈希算法 (Critical #3)
        # MD5 is cryptographically broken, use SHA-256 instead
        return hashlib.sha256(path.read_bytes()).hexdigest()

    def validate_output(self, result: dict[str, Any]) -> dict[str, Any]:
        errors: list[str] = []
        warnings: list[str] = []

        # TODO: Fix empty result handling - 修复空结果处理 (High #9)
        # Ensure consistent return structure with explicit event_count
        if not result:
            errors.append("Result is empty")
            return {
                "valid": False,
                "errors": errors,
                "warnings": warnings,
                "event_count": 0,
                "status": "empty",
            }

        status = result.get("status")
        if status == "error" or status is None:
            events = result.get("events", [])
            for event in events:
                msg = str(event.get("message", "")).lower()
                if any(kw in msg for kw in self.ERROR_KEYWORDS):
                    errors.append(f"Error in output: {msg}")

        events = result.get("events", [])
        for event in events:
            event_type = event.get("type", "")
            msg = str(event.get("message", "")).lower()

            if "error" in event_type or "failure" in event_type:
                errors.append(f"Event error: {msg}")

            if any(kw in msg for kw in self.ERROR_KEYWORDS):
                if not self._is_false_positive(msg):
                    errors.append(f"Error keyword found: {msg}")

        if not events and status == "completed":
            # TODO: Fix empty result handling - 修复空结果处理 (High #9)
            # Add warning instead of just logging
            warnings.append("No events in result, but status is completed")

        return {
            "valid": len(errors) == 0,
            "errors": errors,
            "warnings": warnings,
            "event_count": len(events),
            "status": status,
        }

    def _is_false_positive(self, msg: str) -> bool:
        false_positive_patterns = [
            "no error",
            "without error",
            "error handling",
            "error message",
            "catch error",
        ]
        return any(p in msg for p in false_positive_patterns)

    def validate_file_changes(self) -> dict[str, Any]:
        changed_files = []
        unchanged_files = []

        for path in self._initial_files:
            if not path.exists():
                changed_files.append(f"{path} (deleted)")
                continue

            current_hash = self._hash_file(path)
            if current_hash != self._file_hashes.get(str(path), ""):
                changed_files.append(str(path.relative_to(self.repo_path)))
            else:
                unchanged_files.append(str(path.relative_to(self.repo_path)))

        return {
            "changed": changed_files,
            "unchanged": unchanged_files,
            "has_changes": len(changed_files) > 0,
        }

    def validate_bugfix_or_feature(self, result: dict[str, Any]) -> dict[str, Any]:
        output_check = self.validate_output(result)
        
        # TODO: Fix inconsistent return structure - 修复不一致的返回结构 (High #4)
        # Check for empty/invalid results early
        if output_check.get("status") == "empty" or not result:
            return {
                "valid": False,
                "output_valid": False,
                "output_errors": output_check.get("errors", ["Result is empty"]),
                "files_modified": False,
                "changed_files": [],
                "event_count": 0,
            }
        
        file_check = self.validate_file_changes()

        valid = output_check["valid"] and file_check["has_changes"]

        return {
            "valid": valid,
            "output_valid": output_check["valid"],
            "output_errors": output_check["errors"],
            "files_modified": file_check["has_changes"],
            "changed_files": file_check["changed"],
            "event_count": output_check["event_count"],
        }

    def validate_qa(self, result: dict[str, Any]) -> dict[str, Any]:
        output_check = self.validate_output(result)
        
        # TODO: Fix inconsistent return structure - 修复不一致的返回结构 (High #4)
        # Check for empty/invalid results early
        if output_check.get("status") == "empty" or not result:
            return {
                "valid": False,
                "output_valid": False,
                "output_errors": output_check.get("errors", ["Result is empty"]),
                "files_unchanged": True,
                "changed_files": [],
                "event_count": 0,
            }
        
        file_check = self.validate_file_changes()

        valid = output_check["valid"] and not file_check["has_changes"]

        return {
            "valid": valid,
            "output_valid": output_check["valid"],
            "output_errors": output_check["errors"],
            "files_unchanged": not file_check["has_changes"],
            "changed_files": file_check["changed"],
            "event_count": output_check["event_count"],
        }
