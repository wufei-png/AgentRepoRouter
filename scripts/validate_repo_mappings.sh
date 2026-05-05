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

const supportedCliKeys = new Set(["claude-code", "opencode", "cursor", "codex"]);

function validateNamedAssetMap(kind, assetMap, repoIndex) {
  if (!assetMap || typeof assetMap !== "object" || Array.isArray(assetMap)) {
    fail(`repos[${repoIndex}].${kind} must be an object`);
  }

  for (const [cliName, assetEntries] of Object.entries(assetMap)) {
    if (!supportedCliKeys.has(cliName)) {
      fail(`repos[${repoIndex}].${kind} has an unsupported CLI key: ${cliName}`);
    }
    if (!Array.isArray(assetEntries)) {
      fail(`repos[${repoIndex}].${kind}.${cliName} must be an array`);
    }

    const seenAssetNames = new Set();
    for (const [assetIndex, assetEntry] of assetEntries.entries()) {
      if (!assetEntry || typeof assetEntry !== "object" || Array.isArray(assetEntry)) {
        fail(
          `repos[${repoIndex}].${kind}.${cliName}[${assetIndex}] must be an object`
        );
      }

      const assetKeys = Object.keys(assetEntry).sort();
      const expectedAssetKeys = ["description", "name"];
      if (
        assetKeys.length !== expectedAssetKeys.length ||
        assetKeys.some((key, keyIndex) => key !== expectedAssetKeys[keyIndex])
      ) {
        fail(
          `repos[${repoIndex}].${kind}.${cliName}[${assetIndex}] must contain exactly these keys: ${expectedAssetKeys.join(", ")}`
        );
      }

      for (const key of ["name", "description"]) {
        if (
          typeof assetEntry[key] !== "string" ||
          assetEntry[key].trim() === ""
        ) {
          fail(
            `repos[${repoIndex}].${kind}.${cliName}[${assetIndex}].${key} must be a non-empty string`
          );
        }
      }

      if (seenAssetNames.has(assetEntry.name)) {
        fail(
          `repos[${repoIndex}].${kind}.${cliName} contains a duplicate entry: ${assetEntry.name}`
        );
      }
      seenAssetNames.add(assetEntry.name);
    }
  }
}

const seenRepoPaths = new Set();
for (const [index, repo] of data.repos.entries()) {
  if (!repo || typeof repo !== "object" || Array.isArray(repo)) {
    fail(`repos[${index}] must be an object`);
  }

  const repoKeys = Object.keys(repo).sort();
  const expectedRepoKeys = ["agents", "aliases", "name", "path", "skills"];
  if (
    repoKeys.length !== expectedRepoKeys.length ||
    repoKeys.some((key, keyIndex) => key !== expectedRepoKeys[keyIndex])
  ) {
    fail(
      `repos[${index}] must contain exactly these keys: ${expectedRepoKeys.join(", ")}`
    );
  }

  for (const key of ["name", "path"]) {
    if (typeof repo[key] !== "string" || repo[key].trim() === "") {
      fail(`repos[${index}].${key} must be a non-empty string`);
    }
  }

  if (!repo.path.startsWith("/")) {
    fail(`repos[${index}].path must be an absolute path`);
  }

  if (!Array.isArray(repo.aliases)) {
    fail(`repos[${index}].aliases must be an array`);
  }
  const seenAliases = new Set();
  for (const [aliasIndex, alias] of repo.aliases.entries()) {
    if (typeof alias !== "string" || alias.trim() === "") {
      fail(`repos[${index}].aliases[${aliasIndex}] must be a non-empty string`);
    }
    if (seenAliases.has(alias)) {
      fail(`repos[${index}].aliases contains a duplicate entry: ${alias}`);
    }
    seenAliases.add(alias);
  }

  validateNamedAssetMap("skills", repo.skills, index);
  validateNamedAssetMap("agents", repo.agents, index);

  if (seenRepoPaths.has(repo.path)) {
    fail(`repos contains a duplicate path: ${repo.path}`);
  }
  seenRepoPaths.add(repo.path);
}

process.stdout.write("OK\n");
EOF
