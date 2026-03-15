"""OrchAI package"""

__version__ = "0.1.0"

# TODO: Fix no public API exports - 修复没有公共 API 导出的问题 (Medium #4)
# Define public API
__all__ = [
    "Router",
    "Config",
    "ACPAdapter",
    "ResultValidator",
    "route",
    "load_repos",
    "add_mapping",
]

# Import public classes for convenience
from .router import Router, route, load_repos, add_mapping
from .config import Config
from .acp_adapter import ACPAdapter
from .validator import ResultValidator
