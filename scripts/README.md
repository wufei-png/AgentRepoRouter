# 脚本说明

## AskAny metrics review（OpenCode 定时/一次性任务）

在 [AskAny](https://github.com/wufei-png/AskAny) 项目下用 OpenCode 执行 metrics 功能 review。

### 文件

- `askany_metrics_review_prompt.txt`：metrics 功能 review 提示词。
- `askany_sse_streaming_prompt.txt`：SSE streaming 功能 review 提示词。
- `askany_langfuse_ragas_prompt.txt`：Langfuse tracing and RAGAS RAG metrics 功能 review 提示词。
- `run_askany_metrics_review.sh`：执行脚本，依赖 `npx acpx` 和 OpenCode。可选第一个参数指定提示词文件名（默认 `askany_metrics_review_prompt.txt`）。

### 立即运行

```bash
# 在 AgentRepoRouter 项目根目录
./scripts/run_askany_metrics_review.sh
```

或指定 AskAny 路径：

```bash
ASKANY_DIR=/path/to/AskAny ./scripts/run_askany_metrics_review.sh
```

### 延迟运行（后台）

输出建议写到 `scripts/logs/` 下，例如：

```bash
AGENT_REPO_ROUTER_SCRIPTS="/home/wufei/github.com/wufei-png/AgentRepoRouter/scripts"
LOGS="${AGENT_REPO_ROUTER_SCRIPTS}/logs"
mkdir -p "$LOGS"

# 1h 后 metrics
(sleep 3600 && "$AGENT_REPO_ROUTER_SCRIPTS/run_askany_metrics_review.sh") >> "$LOGS/askany_review_metrics_1h.log" 2>&1 &

# 2h 后 SSE streaming
(sleep 7200 && "$AGENT_REPO_ROUTER_SCRIPTS/run_askany_metrics_review.sh" askany_sse_streaming_prompt.txt) >> "$LOGS/askany_review_sse_2h.log" 2>&1 &

# 3h 后 Langfuse + RAGAS
(sleep 10800 && "$AGENT_REPO_ROUTER_SCRIPTS/run_askany_metrics_review.sh" askany_langfuse_ragas_prompt.txt) >> "$LOGS/askany_review_langfuse_ragas_3h.log" 2>&1 &

# 4h 后 metrics
(sleep 14400 && "$AGENT_REPO_ROUTER_SCRIPTS/run_askany_metrics_review.sh") >> "$LOGS/askany_review_metrics_4h.log" 2>&1 &
```

查看某次任务输出：`tail -f scripts/logs/askany_review_metrics_1h.log`

### 使用 at 定时（若系统已安装 at）

```bash
echo "/home/wufei/github.com/wufei-png/AgentRepoRouter/scripts/run_askany_metrics_review.sh" | at now + 1 hour
```

### 指定提示词

```bash
./scripts/run_askany_metrics_review.sh                              # 默认 metrics
./scripts/run_askany_metrics_review.sh askany_sse_streaming_prompt.txt
./scripts/run_askany_metrics_review.sh askany_langfuse_ragas_prompt.txt
```
