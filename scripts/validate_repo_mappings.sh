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

const rootKeys = Object.keys(data).sort();
const expectedRootKeys = [
  "executionClis",
  "installHosts",
  "installMode",
  "repos",
  "schemaVersion",
];
if (
  rootKeys.length !== expectedRootKeys.length ||
  rootKeys.some((key, keyIndex) => key !== expectedRootKeys[keyIndex])
) {
  fail(`root must contain exactly these keys: ${expectedRootKeys.join(", ")}`);
}

if (data.schemaVersion !== 2) {
  fail("schemaVersion must be 2");
}

if (!["global", "single", "custom"].includes(data.installMode)) {
  fail("installMode must be global, single, or custom");
}

const supportedInstallHosts = new Set([
  "global",
  "openclaw",
  "claude-code",
  "opencode",
  "codex",
  "hermes",
]);

if (!Array.isArray(data.installHosts)) {
  fail("installHosts must be an array");
}

const seenInstallHosts = new Set();
for (const [index, host] of data.installHosts.entries()) {
  if (typeof host !== "string" || host.trim() === "") {
    fail(`installHosts[${index}] must be a non-empty string`);
  }
  if (!supportedInstallHosts.has(host)) {
    fail(`installHosts[${index}] has an unsupported host: ${host}`);
  }
  if (seenInstallHosts.has(host)) {
    fail(`installHosts contains a duplicate entry: ${host}`);
  }
  seenInstallHosts.add(host);
}

if (!Array.isArray(data.executionClis)) {
  fail("executionClis must be an array");
}

const supportedCliKeys = new Set(["claude-code", "opencode", "cursor", "codex", "hermes"]);

const seenExecutionClis = new Set();
for (const [index, cliName] of data.executionClis.entries()) {
  if (typeof cliName !== "string" || cliName.trim() === "") {
    fail(`executionClis[${index}] must be a non-empty string`);
  }
  if (!supportedCliKeys.has(cliName)) {
    fail(`executionClis[${index}] has an unsupported CLI: ${cliName}`);
  }
  if (seenExecutionClis.has(cliName)) {
    fail(`executionClis contains a duplicate entry: ${cliName}`);
  }
  seenExecutionClis.add(cliName);
}

if (!Array.isArray(data.repos)) {
  fail("repos must be an array");
}

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
