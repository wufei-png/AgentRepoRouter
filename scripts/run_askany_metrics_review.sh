#!/usr/bin/env bash
# 在 AskAny 项目下用 OpenCode 执行 review 任务
# 用法: ./scripts/run_askany_metrics_review.sh [prompt_file]
# 可选 prompt_file 默认 askany_metrics_review_prompt.txt，可选 askany_sse_streaming_prompt.txt、askany_langfuse_ragas_prompt.txt

set -e
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASKANY_DIR="${ASKANY_DIR:-/home/wufei/github.com/wufei-png/AskAny}"
PROMPT_NAME="${1:-askany_metrics_review_prompt.txt}"
PROMPT_FILE="${REPO_ROOT}/scripts/${PROMPT_NAME}"

if [[ ! -d "$ASKANY_DIR" ]]; then
  echo "Error: AskAny dir not found: $ASKANY_DIR"
  exit 1
fi
if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "Error: Prompt file not found: $PROMPT_FILE"
  exit 1
fi

PROMPT="$(cat "$PROMPT_FILE")"
echo "Running OpenCode in $ASKANY_DIR at $(date -Iseconds)"
cd "$ASKANY_DIR"
exec npx acpx@latest --cwd "$ASKANY_DIR" opencode exec "$PROMPT"
