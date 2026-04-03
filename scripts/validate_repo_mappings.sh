#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <repo_mappings.json>" >&2
    exit 1
fi

TARGET_FILE="$1"

if [ ! -f "$TARGET_FILE" ]; then
    echo "Error: repo mappings file not found: $TARGET_FILE" >&2
    exit 1
fi

node - "$TARGET_FILE" <<'EOF'
const fs = require("node:fs");
const path = process.argv[2];

function fail(message) {
  console.error(`Error: ${message}`);
  process.exit(1);
}

let raw;
try {
  raw = fs.readFileSync(path, "utf8");
} catch (error) {
  fail(`unable to read ${path}: ${error.message}`);
}

let data;
try {
  data = JSON.parse(raw);
} catch (error) {
  fail(`invalid JSON in ${path}: ${error.message}`);
}

if (!data || typeof data !== "object" || Array.isArray(data)) {
  fail("root must be a JSON object");
}

if (data.schemaVersion !== 1) {
  fail("schemaVersion must be 1");
}

if (!Array.isArray(data.agents)) {
  fail("agents must be an array");
}

const seenAgents = new Set();
for (const [index, agent] of data.agents.entries()) {
  if (typeof agent !== "string" || agent.trim() === "") {
    fail(`agents[${index}] must be a non-empty string`);
  }
  if (seenAgents.has(agent)) {
    fail(`agents contains a duplicate entry: ${agent}`);
  }
  seenAgents.add(agent);
}

if (!Array.isArray(data.repos)) {
  fail("repos must be an array");
}

const seenRepoNames = new Set();
for (const [index, repo] of data.repos.entries()) {
  if (!repo || typeof repo !== "object" || Array.isArray(repo)) {
    fail(`repos[${index}] must be an object`);
  }

  for (const key of ["name", "path", "type"]) {
    if (typeof repo[key] !== "string" || repo[key].trim() === "") {
      fail(`repos[${index}].${key} must be a non-empty string`);
    }
  }

  if (!repo.path.startsWith("/")) {
    fail(`repos[${index}].path must be an absolute path`);
  }

  if (seenRepoNames.has(repo.name)) {
    fail(`repos contains a duplicate name: ${repo.name}`);
  }
  seenRepoNames.add(repo.name);
}

process.stdout.write("OK\n");
EOF
