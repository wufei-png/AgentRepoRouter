# Deployment Guide

## Environment

- Runtime: Node.js 24
- Process manager: systemd user service
- Health check: `openclaw health --json`

## Steps

1. Install dependencies with `pnpm install`.
2. Validate configuration before rollout.
3. Deploy the new router skill and `repo_mappings.json`.
4. Run `openclaw health --json` to confirm the gateway is healthy.
5. Open the dashboard with `openclaw dashboard --no-open` if you need the URL only.
