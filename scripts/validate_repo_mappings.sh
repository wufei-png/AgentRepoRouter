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

const supportedSkillKeys = new Set(["claude-code", "opencode", "cursor", "codex"]);
const seenRepoPaths = new Set();
for (const [index, repo] of data.repos.entries()) {
  if (!repo || typeof repo !== "object" || Array.isArray(repo)) {
    fail(`repos[${index}] must be an object`);
  }

  const repoKeys = Object.keys(repo).sort();
  const expectedRepoKeys = ["aliases", "name", "path", "skills"];
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

  if (!repo.skills || typeof repo.skills !== "object" || Array.isArray(repo.skills)) {
    fail(`repos[${index}].skills must be an object`);
  }

  for (const [cliName, skillEntries] of Object.entries(repo.skills)) {
    if (!supportedSkillKeys.has(cliName)) {
      fail(`repos[${index}].skills has an unsupported CLI key: ${cliName}`);
    }
    if (!Array.isArray(skillEntries)) {
      fail(`repos[${index}].skills.${cliName} must be an array`);
    }

    const seenSkillNames = new Set();
    for (const [skillIndex, skillEntry] of skillEntries.entries()) {
      if (!skillEntry || typeof skillEntry !== "object" || Array.isArray(skillEntry)) {
        fail(
          `repos[${index}].skills.${cliName}[${skillIndex}] must be an object`
        );
      }

      const skillKeys = Object.keys(skillEntry).sort();
      const expectedSkillKeys = ["description", "name"];
      if (
        skillKeys.length !== expectedSkillKeys.length ||
        skillKeys.some((key, keyIndex) => key !== expectedSkillKeys[keyIndex])
      ) {
        fail(
          `repos[${index}].skills.${cliName}[${skillIndex}] must contain exactly these keys: ${expectedSkillKeys.join(", ")}`
        );
      }

      for (const key of ["name", "description"]) {
        if (
          typeof skillEntry[key] !== "string" ||
          skillEntry[key].trim() === ""
        ) {
          fail(
            `repos[${index}].skills.${cliName}[${skillIndex}].${key} must be a non-empty string`
          );
        }
      }

      if (seenSkillNames.has(skillEntry.name)) {
        fail(
          `repos[${index}].skills.${cliName} contains a duplicate skill: ${skillEntry.name}`
        );
      }
      seenSkillNames.add(skillEntry.name);
    }
  }

  if (seenRepoPaths.has(repo.path)) {
    fail(`repos contains a duplicate path: ${repo.path}`);
  }
  seenRepoPaths.add(repo.path);
}

process.stdout.write("OK\n");
EOF
